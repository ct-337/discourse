# frozen_string_literal: true

# Export topic data for import into another forum
# Usage in Rails console:
#   topic_id = 123
#   exported_data = load(Rails.root.join('script/export_topic.rb'))
#   puts JSON.pretty_generate(exported_data)
#   # Or save to file:
#   File.write("topic_#{topic_id}_export.json", JSON.pretty_generate(exported_data))

def export_topic(topic_id)
  topic = Topic.includes(posts: [:user, :_custom_fields]).find(topic_id)

  amazonian_group_id = SiteSetting.amazonian_group_id.to_i
  amazonian_group = Group.find_by(id: amazonian_group_id) if amazonian_group_id > 0

  # Get all posts in order
  posts = topic.posts.order(:post_number)

  exported_posts = posts.map do |post|
    user = post.user

    # Get user's group IDs and names
    user_groups = user.groups.pluck(:id, :name).map { |id, name| { id: id, name: name } }

    # Check if user is in Amazonian group
    is_amazonian = amazonian_group && user.groups.exists?(id: amazonian_group.id)

    # Get post custom fields
    custom_fields = post.custom_fields || {}
    category_expert_post_value = custom_fields['category_expert_post']

    {
      post_number: post.post_number,
      raw: post.raw,
      created_at: post.created_at,
      user: {
        username: user.username,
        email: user.email,
        name: user.name,
        admin: user.admin,
        moderator: user.moderator,
        groups: user_groups,
        trust_level: user.trust_level
      },
      is_amazonian: is_amazonian,
      custom_fields: {
        category_expert_post: category_expert_post_value
      }
    }
  end

  # Get topic tags
  topic_tags = topic.tags.pluck(:name)

  {
    topic: {
      title: topic.title,
      category_id: topic.category_id,
      category_name: topic.category&.name,
      tags: topic_tags,
      created_at: topic.created_at,
      archetype: topic.archetype
    },
    posts: exported_posts,
    metadata: {
      exported_at: Time.zone.now,
      source_topic_id: topic.id,
      amazonian_group_name: amazonian_group&.name,
      post_count: posts.count
    }
  }
end

# If $topic_id is defined in the console before loading this script, use it
# and store result in $exported_topic_data
if defined?($topic_id) && $topic_id
  result = export_topic($topic_id)
  $exported_topic_data = result
  puts "\nExported topic '#{result[:topic][:title]}' with #{result[:posts].count} posts"
  puts "Data stored in $exported_topic_data"
  puts "\nTo save to file:"
  puts "  File.write('topic_#{$topic_id}_export.json', JSON.pretty_generate($exported_topic_data))"
  result
else
  puts "Usage:"
  puts "  $topic_id = 123"
  puts "  load(Rails.root.join('script/export_topic.rb'))"
  puts "  # Data will be in $exported_topic_data"
  puts ""
  puts "Or call the function directly:"
  puts "  load(Rails.root.join('script/export_topic.rb'))"
  puts "  exported_data = export_topic(123)"
  nil
end
