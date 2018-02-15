require 'scraperwiki'
require 'mechanize'

if ( ENV['MORPH_PERIOD'] ) &&
   ( ENV['MORPH_PERIOD'] == "thismonth" ||
     ENV['MORPH_PERIOD'] == "lastmonth" ||
     ENV['MORPH_PERIOD'].to_i != 0 &&
     ENV['MORPH_PERIOD'].to_i == 7 ||
     ENV['MORPH_PERIOD'].to_i == 14 )
  if ( ENV['MORPH_PERIOD'].to_i == 0 )
    period = ENV['MORPH_PERIOD']
  else
    period = "last" + ENV['MORPH_PERIOD'].to_s + "days"
  end
else
  period = "thismonth"
end

base_url = "http://eplanning.parracity.nsw.gov.au/Pages/XC.Track/SearchApplication.aspx"
comment_url = "mailto:council@cityofparramatta.nsw.gov.au"

# meaning of t parameter
# %23427 - Development Applications
# %23437 - Constuction Certificates
# %23434,%23435 - Complying Development Certificates
# %23475 - Building Certificates
# %23440 - Tree Applications
url = base_url + "?d=" + period + "&t=%23437,%23437,%23434,%23435,%23475,%23440"

agent = Mechanize.new
page = agent.get(url)

results = page.search('div.result')
puts results.count.to_s + " Development Applications to scrape. Period: " + period

results.each do |result|
  info_url = base_url + "?" + result.search('a.search')[0]['href'].strip.split("?")[1]
  detail_page = agent.get(info_url);
  re = /\$\s*[0-9,]*/

  council_reference = detail_page.search('h2').text.split("\n")[0].strip
  stat = detail_page.search('strong').text.split("\n")[0].strip
  cost_re = detail_page.search("div#b_ctl00_ctMain_info_app").text.match re
  cost = cost_re[0]
  description = detail_page.search("div#b_ctl00_ctMain_info_app").text.split("Status:")[0].strip.split.join(" ")
  date_received = detail_page.search("div#b_ctl00_ctMain_info_app").text.split("Lodged: ")[1].split[0]
  date_received = Date.parse(date_received.to_s)
  address = detail_page.search("div#b_ctl00_ctMain_info_prop").text.split("\n")[0].squeeze(' ')

  record = {
    'council_reference' => council_reference,
    'description'       => description,
    'cost'		         => cost,
    'status'		      => stat,
    'date_received'     => date_received,
    'address'           => address,
    'info_url'          => info_url,
    'comment_url'       => comment_url,
    'date_scraped'      => Date.today.to_s
  }

  if (ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true)
    puts "Saving record " + record['council_reference'] + ", " + record['address']+", " + record['cost']+", "+record['status']
    #puts record
    ScraperWiki.save_sqlite(['council_reference'], record)
  else
    puts "Skipping already saved record " + record['council_reference']
  end
end

