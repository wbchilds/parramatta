require 'scraperwiki'
require 'rss/2.0'
require 'date'
require 'mechanize'

if ( ENV['MORPH_PERIOD'] && ENV['MORPH_PERIOD'].is_a )
  period = ENV['MORPH_PERIOD']
else
  period = 7
end

base_url = "http://eplanning.parracity.nsw.gov.au/Pages/XC.Track/SearchApplication.aspx"
url = base_url + "?o=rss&d=last" + period.to_s + "days"

agent = Mechanize.new

page = agent.get(url)
form = page.forms.first
form.checkbox_with(:name => /Agree/).check
page = form.submit(form.button_with(:name => /Agree/))

t = page.content.to_s
# I've no idea why the RSS feed says it's encoded as utf-16 when as far as I can tell it isn't
# Hack it by switching it back to utf-8
t.gsub!("utf-16", "utf-8")

feed = RSS::Parser.parse(t, false)

feed.channel.items.each do |item|
  address = item.description[/(.*\d{4})\./, 1]
  description = item.description[/\d{4}\. (.*)/, 1]
  council_reference = item.title.split(' ')[0]

  if (address && description) && (!address.empty? && !description.empty?)
    record = {
      'council_reference' => council_reference,
      'description'       => description.squeeze(' '),
      # Have to make this a string to get the date library to parse it
      'date_received'     => Date.parse(item.pubDate.to_s),
      'address'           => address.squeeze(' '),
      'info_url'          => base_url + "#{item.link}",
      # Comment URL is actually an email address but I think it's best
      # they go to the detail page
      'comment_url'       => base_url + "#{item.link}",
      'date_scraped'      => Date.today.to_s
    }
    if (ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true)
      ScraperWiki.save_sqlite(['council_reference'], record)
    else
       puts "Skipping already saved record " + record['council_reference']
    end
  else
    puts "Skipping #{council_reference} as the address and/or description can't be parsed"
  end
end

