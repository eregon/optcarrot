require 'csv'

as_columns = { 'frame' => [] }

ARGV.map { |file|
  interpreter = File.basename(file, '.*')
  data = CSV.read(file).reject { |frame, value|
    frame =~ /^(fps|checksum):/
  }.drop(1).map { |frame, value|
    [Integer(frame), Float(value)]
  }

  frames = data.map(&:first)
  fps = data.map(&:last)

  as_columns['frame'] = frames if frames.size > as_columns['frame'].size
  as_columns[interpreter] = fps
}

p as_columns.keys

CSV.open("fps-history.csv", "wb") do |csv|
  columns = as_columns.keys
  csv << columns
  as_columns['frame'].each { |frame|
    csv << columns.map { |col| as_columns[col][frame] }
  }
end
