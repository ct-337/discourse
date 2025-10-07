# frozen_string_literal: true

# Import topic data from exported JSON
# Usage in Rails console:
#   exported_data = JSON.parse(File.read("topic_123_export.json"))
#   imported_topic = load(Rails.root.join('script/import_topic.rb'))
#   puts "Imported topic ID: #{imported_topic.id}"

def import_topic(data, options = {})
  # Options
  target_category_id = options[:category_id] # Override category if needed
  dry_run = options[:dry_run] || false

  topic_data = data['topic']
  posts_data = data['posts']
  amazonian_group_id = SiteSetting.amazonian_group_id.to_i

  # Validate we have data
  raise "No topic data provided" if topic_data.nil?
  raise "No posts data provided" if posts_data.nil? || posts_data.empty?

  # Get or create Amazonian group
  amazonian_group = Group.find_by(id: amazonian_group_id) if amazonian_group_id > 0

  # Find or create users
  users_cache = {}
  posts_data.each do |post_data|
    user_data = post_data['user']
    username = user_data['username']

    next if users_cache[username]

    user = User.find_by(username: username)

    if user.nil?
      # Create user with matching username
      puts "Creating user: #{username}"
      user = User.create!(
        username: username,
        email: user_data['email'] || "#{username}@imported.local",
        name: user_data['name'] || username,
        password: SecureRandom.hex(32),
        approved: true,
        active: true,
        trust_level: user_data['trust_level'] || 1
      )

      # Set admin/moderator status
      user.update!(admin: true) if user_data['admin']
      user.update!(moderator: true) if user_data['moderator']
    else
      puts "Found existing user: #{username}"
    end

    # Add user to groups
    if user_data['groups'].present?
      user_data['groups'].each do |group_info|
        group_name = group_info['name']
        group = Group.find_by(name: group_name)

        if group && !user.groups.exists?(id: group.id)
          puts "  Adding #{username} to group: #{group_name}"
          group.add(user) unless dry_run
        end
      end
    end

    # Add Amazonian users to Amazonian group
    if post_data['is_amazonian'] && amazonian_group
      unless user.groups.exists?(id: amazonian_group.id)
        puts "  Adding #{username} to Amazonian group: #{amazonian_group.name}"
        amazonian_group.add(user) unless dry_run
      end
    end

    users_cache[username] = user
  end

  return { dry_run: true, users: users_cache.keys } if dry_run

  # Create topic with first post
  first_post_data = posts_data.first
  first_user = users_cache[first_post_data['user']['username']]

  puts "\nCreating topic: #{topic_data['title']}"

  # Determine category
  category_id = target_category_id || topic_data['category_id']

  # Create the topic and first post
  post_creator = PostCreator.new(
    first_user,
    title: topic_data['title'],
    raw: first_post_data['raw'],
    category: category_id,
    tags: topic_data['tags'],
    archetype: topic_data['archetype'] || 'regular',
    skip_validations: options[:skip_validations] || false
  )

  result = post_creator.create

  if post_creator.errors.present?
    raise "Failed to create topic: #{post_creator.errors.full_messages.join(', ')}"
  end

  topic = result.topic
  first_post = result

  puts "  Created topic ID: #{topic.id}"
  puts "  Created first post ID: #{first_post.id}"

  # Set custom fields on first post if needed
  if first_post_data['custom_fields'] && first_post_data['custom_fields']['category_expert_post']
    first_post.custom_fields['category_expert_post'] = first_post_data['custom_fields']['category_expert_post']
    first_post.save_custom_fields
    puts "    Set category_expert_post custom field"
  end

  # Create remaining posts in order
  posts_data[1..-1].each do |post_data|
    user = users_cache[post_data['user']['username']]

    puts "  Creating post #{post_data['post_number']} by #{user.username}"

    post_creator = PostCreator.new(
      user,
      raw: post_data['raw'],
      topic_id: topic.id,
      skip_validations: options[:skip_validations] || false
    )

    post = post_creator.create

    if post_creator.errors.present?
      puts "    Warning: Failed to create post: #{post_creator.errors.full_messages.join(', ')}"
      next
    end

    puts "    Created post ID: #{post.id}"

    # Set custom fields if needed
    if post_data['custom_fields'] && post_data['custom_fields']['category_expert_post']
      post.custom_fields['category_expert_post'] = post_data['custom_fields']['category_expert_post']
      post.save_custom_fields
      puts "      Set category_expert_post custom field"
    end
  end

  # Reload topic to get updated stats
  topic.reload

  puts "\nImport complete!"
  puts "  Topic ID: #{topic.id}"
  puts "  Posts created: #{topic.posts.count}"
  puts "  URL: #{Discourse.base_url}/t/#{topic.slug}/#{topic.id}"

  topic
end

# If $exported_data is defined in the console before loading this script, use it
if defined?($exported_data) && $exported_data
  result = import_topic($exported_data)
  $imported_topic = result
  puts "\nImported topic stored in $imported_topic"
  result
elsif defined?($exported_topic_data) && $exported_topic_data
  # Use the global variable from export script if available
  result = import_topic($exported_topic_data)
  $imported_topic = result
  puts "\nImported topic stored in $imported_topic"
  result
else
  puts "Usage:"
  puts "  $exported_data = JSON.parse(File.read('topic_123_export.json'))"
  puts "  load(Rails.root.join('script/import_topic.rb'))"
  puts "  # Topic will be imported and stored in $imported_topic"
  puts ""
  puts "Or call the function directly:"
  puts "  load(Rails.root.join('script/import_topic.rb'))"
  puts "  imported_topic = import_topic(exported_data)"
  nil
end
