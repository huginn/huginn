ICONS_DIR      = 'public'
ORIGINAL_IMAGE = 'media/huginn-icon-square.svg'

desc "Generate site icons from #{ORIGINAL_IMAGE}"
task :icons => 'icon:all'

namespace :icon do
  # iOS
  task :all => :ios

  [
    57, 114,
    60, 120, 180,
    72, 144,
    76, 152,
  ].each do |width|
    sizes = '%1$dx%1$d' % width
    filename = "apple-touch-icon-#{sizes}.png"
    icon = File.join(ICONS_DIR, filename)

    file icon => ORIGINAL_IMAGE do |t|
      puts "Generating #{t.name}"
      convert_image t.source, t.name, width: width
    end

    task :ios => icon
  end

  # Android
  task :all => :android

  android_icons = [
    36, 72, 144,
    48, 96, 192,
  ].map do |width|
    sizes = '%1$dx%1$d' % width
    filename = "android-chrome-#{sizes}.png" % width
    icon = File.join(ICONS_DIR, filename)

    file icon => ORIGINAL_IMAGE do |t|
      puts "Generating #{t.name}"
      convert_image t.source, t.name, width: width, round: true
    end

    task :android => icon

    {
      src: "/#{filename}",
      sizes: sizes,
      type: 'image/png',
      density: (width / 48.0).to_s,
    }
  end

  manifest = File.join(ICONS_DIR, 'manifest.json')

  file manifest => __FILE__ do |t|
    puts "Generating #{t.name}"
    require 'json'
    json = {
      name: 'Huginn',
      icons: android_icons
    }
    File.write(t.name, JSON.pretty_generate(json))
  end

  task :android => manifest
end

require 'mini_magick'

def convert_image(source, target, options = {})  # width: nil, round: false
  ext = target[/(?<=\.)[^.]+\z/] || 'png'
  original = MiniMagick::Image.open(source)

  result = original
  result.format ext

  if width = options[:width]
    result.thumbnail '%1$dx%1$d>' % width
  else
    width = result[:width]
  end

  if options[:round]
    radius = (Rational(80, 512) * width).round

    mask = MiniMagick::Image.create(ext) { |tmp| result.write(tmp) }

    mask.mogrify do |image|
      image.alpha 'transparent'
      image.background 'none'
      image.fill 'white'
      image.draw 'roundrectangle 0,0,%1$d,%1$d,%2$d,%2$d' % [width, radius]
    end

    result = result.composite(mask) do |image|
      image.alpha 'set'
      image.compose 'DstIn'
    end
  end

  result.strip
  result.write(target)
end
