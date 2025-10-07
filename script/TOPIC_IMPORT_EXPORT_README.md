# Topic Import/Export Scripts

These scripts allow you to export topics from one Discourse forum and import them into another, maintaining a 1:1 mapping of content, users, and permissions.

## Features

- Exports complete topic data including all posts in order
- Preserves user information (username, admin/moderator status, group memberships)
- Maintains Amazonian user designation and `category_expert_post` custom fields
- Finds or creates users with matching usernames and permissions
- Recreates topics with exact post order

## Prerequisites

- Access to Rails console on both source and destination forums
- Appropriate permissions to create users and topics
- `SiteSetting.amazonian_group_id` configured on both forums

## Export Process

### On Source Forum

1. Open Rails console:
   ```bash
   rails console
   ```

2. Export a topic:
   ```ruby
   # Set the topic ID you want to export (use $ for global variable)
   $topic_id = 123

   # Load and run the export script
   load(Rails.root.join('script/export_topic.rb'))
   # Data is now in $exported_topic_data

   # Save to JSON file
   File.write("topic_#{$topic_id}_export.json", JSON.pretty_generate($exported_topic_data))

   # Or view the data
   puts JSON.pretty_generate($exported_topic_data)
   ```

3. Copy the JSON file to your destination forum server

## Import Process

### On Destination Forum

1. Open Rails console:
   ```bash
   rails console
   ```

2. Import the topic:

   **Option A: From file**
   ```ruby
   # Load the exported data from file
   $exported_data = JSON.parse(File.read("topic_123_export.json"))

   # Load and run the import script
   load(Rails.root.join('script/import_topic.rb'))
   # Topic is now in $imported_topic
   ```

   **Option B: Direct JSON assignment (no files needed)**
   ```ruby
   # Just paste the JSON hash directly
   $exported_data = {
     "topic" => {
       "title" => "My Topic",
       "category_id" => 5,
       # ... rest of JSON
     },
     "posts" => [
       # ... posts data
     ]
   }

   # Load and run the import script
   load(Rails.root.join('script/import_topic.rb'))
   # Topic is now in $imported_topic
   ```

   **Check the results:**
   ```ruby
   puts "Topic imported with ID: #{$imported_topic.id}"
   puts "URL: #{Discourse.base_url}/t/#{$imported_topic.slug}/#{$imported_topic.id}"
   ```

### Import Options

You can pass options to customize the import:

```ruby
# Override the target category
imported_topic = import_topic(exported_data, category_id: 5)

# Dry run (creates users but not the topic)
result = import_topic(exported_data, dry_run: true)
puts "Would create users: #{result[:users].join(', ')}"

# Skip validations (use with caution)
imported_topic = import_topic(exported_data, skip_validations: true)
```

## What Gets Exported

### Topic Data
- Title
- Category ID and name
- Tags
- Archetype (regular, private message, etc.)
- Creation timestamp

### Post Data (for each post in order)
- Post number
- Raw markdown content
- Creation timestamp
- Custom fields (especially `category_expert_post`)

### User Data (for each post author)
- Username
- Email
- Name
- Admin/moderator status
- Trust level
- Group memberships
- Amazonian user designation

## What Gets Imported

### User Handling
- **Existing users**: If a user with the same username exists, it will be used
- **New users**: If no matching user exists, one will be created with:
  - Matching username
  - Email from export or generated as `{username}@imported.local`
  - Random secure password
  - Matching admin/moderator status
  - Matching trust level
  - Added to matching groups (where they exist)
  - Added to Amazonian group if designated

### Topic Creation
- Topic is created with the first post
- Remaining posts are created in exact order
- Custom fields are set on posts (especially `category_expert_post` for Amazonian users)
- Category can be overridden with `category_id` option

## Amazonian User Handling

The scripts automatically handle Amazonian users:

1. **Export**: Identifies users in the group specified by `SiteSetting.amazonian_group_id`
2. **Import**: Adds those users to the destination forum's Amazonian group
3. **Custom Field**: Sets `category_expert_post` custom field with the Amazonian group name

## Example Workflow

### With Files
```ruby
# === ON SOURCE FORUM ===
$topic_id = 456
load(Rails.root.join('script/export_topic.rb'))
File.write("topic_456_export.json", JSON.pretty_generate($exported_topic_data))
# Transfer topic_456_export.json to destination server

# === ON DESTINATION FORUM ===
$exported_data = JSON.parse(File.read("topic_456_export.json"))
load(Rails.root.join('script/import_topic.rb'))

# Verify the import
puts "Original post count: #{$exported_data['metadata']['post_count']}"
puts "Imported post count: #{$imported_topic.posts.count}"
```

### Without Files (Direct Copy/Paste)
```ruby
# === ON SOURCE FORUM ===
$topic_id = 456
load(Rails.root.join('script/export_topic.rb'))

# Copy the output of this command:
puts $exported_topic_data.inspect

# === ON DESTINATION FORUM ===
# Paste the hash data directly:
$exported_data = { ... paste here ... }

load(Rails.root.join('script/import_topic.rb'))

# Verify the import
puts "Imported post count: #{$imported_topic.posts.count}"
```

## Troubleshooting

### Users Not Created
- Check that email addresses are valid
- Verify user creation permissions
- Review any validation errors in console output

### Posts Missing Custom Fields
- Verify `SiteSetting.amazonian_group_id` is set correctly
- Check that users are properly added to Amazonian group
- Review console output for custom field setting messages

### Category Not Found
- Specify target category explicitly: `import_topic(data, category_id: 5)`
- Or create the category before importing

### Groups Not Found
- Groups are optional - users will be created even if groups don't exist
- Create matching groups before import if group membership is important

## Notes

- Topic IDs will be different on the destination forum
- URLs will be different based on the destination forum's base URL
- Timestamps are preserved but can differ slightly due to processing time
- The import is idempotent for users (won't duplicate existing users)
- Large topics may take time to import - monitor console output for progress
