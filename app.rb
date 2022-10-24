require "sqlite3"
require "json"
require "fileutils"
require 'cgi'

source_db_file = "/Users/msw/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/database.sqlite"
db_file =        "/tmp/#{rand.to_s.slice 2..}.sqlite"

# Backup the database

FileUtils.cp source_db_file, db_file

# Open a database
db = SQLite3::Database.new db_file

db.results_as_hash = true

# Get all the notes with the "public" tag
query = <<~SQL.strip
  SELECT
    ZTEXT,
    ZSFNOTE.ZTITLE,
    ZCREATIONDATE,
    ZSFNOTE.ZMODIFICATIONDATE,
    ZSFNOTE.ZCREATIONDATE,
    ZSFNOTE.ZLASTEDITINGDEVICE
  FROM ZSFNOTE
  INNER JOIN Z_7TAGS ON Z_7TAGS.Z_7NOTES = ZSFNOTE.Z_PK
  INNER JOIN ZSFNOTETAG ON Z_7TAGS.Z_14TAGS = ZSFNOTETAG.Z_PK
  WHERE ZSFNOTETAG.ZTITLE = 'public'
  AND ZARCHIVEDDATE IS NULL
  AND ZPASSWORD IS NULL
SQL


def process_row row
  filtered_fields = Hash.new
  filtered_fields[:text] =         row["ZTEXT"]
  filtered_fields[:title] =        row["ZTITLE"]
  filtered_fields[:created_at] =   row["ZCREATIONDATE"]
  filtered_fields[:updated_at] =   row["ZMODIFICATIONDATE"]
  filtered_fields[:last_edit_on] = row["ZLASTEDITINGDEVICE"]

  filtered_fields
end

# Go through them all
results = []
db.execute query do |row|
  pr = process_row(row)
  results << pr
  Dir.mkdir('blog') unless Dir.exist?('blog')
  pr[:text].scan(/\[(image|file)\:([^\]]+)\]/).each do |(type, path)|
    puts "Publishing #{path}"
    # Copy the file from Bear to our publishing directory
    puts "Creating blog/#{File.dirname path}"
    FileUtils.mkdir_p "./blog/#{File.dirname path}"
    puts "Copying to blog/#{File.dirname path}"
    bear_file_store = "/Users/msw/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/Local Files/Note #{type.capitalize}s"
    FileUtils.cp "#{bear_file_store}/#{path}", "./blog/#{path}"
    puts "#{bear_file_store}/#{path}"
    # Modify the markdown to include the insert
    if type == 'image'
      md_image = "![](./#{path.gsub(" ", "%20")})"
      pr[:text] = pr[:text].sub("[image:#{path}]", md_image)
    end
  end
  puts "Publishing #{pr[:title]}"
  File.write("blog/#{pr[:created_at]}.md", pr[:text])
end

puts results.to_json

FileUtils.rm db_file
