def load_gem(name, version=nil)
  require 'rubygems'

  begin
    gem name, version
  rescue LoadError
    version = "--version '#{version}'" unless version.nil?
    system("gem install #{name} #{version}")
    Gem.clear_paths
    retry
  end

end

load_gem 'selenium-webdriver'
load_gem 'browsermob-proxy'
load_gem 'google_drive'
load_gem 'chromedriver-helper', '~> 1.0'

require 'selenium/webdriver'
require 'browsermob/proxy'
require 'google_drive'
require_relative './Page.rb'
require_relative './Widget.rb'


#TODO TIMEOUTS
#TODO POSITION SHEETS

###BrowserMob
servers = [BrowserMob::Proxy::Server.new('/Users/llempel/Documents/browsermob-proxy-2.1.1/bin/browsermob-proxy'),
           BrowserMob::Proxy::Server.new('/Users/llempel/Documents/browsermob-proxy-2.1.1/bin/browsermob-proxy'),
           BrowserMob::Proxy::Server.new('/Users/llempel/Documents/browsermob-proxy-2.1.1/bin/browsermob-proxy')]#=> #<BrowserMob::Proxy::Server:0x000001022c6ea8 ...>

servers.each do |server|
  server.start
end

proxy = [servers[0].create_proxy, servers[1].create_proxy, servers[2].create_proxy] #=> #<BrowserMob::Proxy::Client:0x0000010224bdc0 ...>
###end BrowserMob


###Selenium Drivers
caps = [Selenium::WebDriver::Remote::Capabilities.chrome(:proxy => proxy[0].selenium_proxy),
        Selenium::WebDriver::Remote::Capabilities.chrome(:proxy => proxy[1].selenium_proxy),
        Selenium::WebDriver::Remote::Capabilities.chrome(:proxy => proxy[2].selenium_proxy)]

drivers = [Selenium::WebDriver.for(:chrome, :desired_capabilities => caps[0]),
           Selenium::WebDriver.for(:chrome, :desired_capabilities => caps[1], :switches => %w[--user-agent=Mozilla/5.0(iPad; U; CPU iPhone OS 3_2 like Mac OS X; en-us) AppleWebKit/531.21.10 (KHTML, like Gecko) Version/4.0.4 Mobile/7B314 Safari/531.21.10]),
           Selenium::WebDriver.for(:chrome, :desired_capabilities => caps[2], :switches => %w[--user-agent=Mozilla/5.0 (iPhone; CPU iPhone OS 9_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13B143 Safari/601.1])]

platform = ['Desktop', 'Tablet', 'Mobile']

drivers[1].manage.window.resize_to(768, 1024)
drivers[2].manage.window.resize_to(375, 667)
###end Selenium Drivers


###Sheets integration
#TODO OAUTH
session = GoogleDrive::Session.from_config('config.json')
if (Date.today.cweek%2 == 1)
  ws = session.spreadsheet_by_key('11SNfwSMrBjLaaE9qtS1q7hrRaDNIqiHFo5cmCdVqj2E').worksheets[0]
else
  ws = session.spreadsheet_by_key('11SNfwSMrBjLaaE9qtS1q7hrRaDNIqiHFo5cmCdVqj2E').worksheets[1]
end

urls = []

results_array = []
row_array = []

#Create array from sheet URL list

=begin
(46..50).each do |row|
  urls << ws[row, 1]
end
=end
urls << ws[51, 1]
###end Sheets integration


#Method for adding platform
  def add_to_map(h, platform, widget_id)
    if h.include?(widget_id)
      p = h[widget_id] + ', ' + platform
      h.store(widget_id, p)
    else
      h.store(widget_id, platform)
    end
  end

#Loop through each URL
urls.each do |url|
  dupe_widgets = Hash.new
  hidden_widgets = Hash.new
  serv_iss_widgets = Hash.new
  hidden_ads_widgets = Hash.new
  competitors = Hash.new
  load_times = Hash.new
  page_widget_ids = ["", "", ""]
  driver_index = 0


  #Loop through each platform
  drivers.each do |browser|

    cur_page = Page.new
    page_loaded = true
    page_widgets = []
    load_time = ""
    revcontent_found = false
    taboola_found = false
    disqus_found = false
    zergnet_found = false

    #check for MSN
    if url.include?('msn.com')
      if driver_index == 2
        url = url.split("?fdhead=")[0]+'?fdhead=m-al-ar-ob'
      else
        url = url.split("?fdhead=")[0]+'?fdhead=al-ar-obvnext'
      end
    end

    #Instantiate new proxy file
    proxy[driver_index].new_har(:capture_content => true)

    begin
      drivers[driver_index].get(url)
      puts "Testing #{url} on #{platform[driver_index]}"
      browser.execute_script("window.stop();")

      browser.execute_script("window.scrollTo(0,Math.max(document.documentElement.scrollHeight," +
                        "document.body.scrollHeight,document.documentElement.clientHeight) - 100);")
      browser.execute_script("window.stop();")

      wait = Selenium::WebDriver::Wait.new(:timeout => 5)
      begin
        page_widgets = wait.until { browser.find_element(:xpath, "//div[contains(@class,'OUTBRAIN')]") }
        page_widgets = browser.find_elements(:xpath, "//div[contains(@class,'OUTBRAIN')]")
        page_widgets += browser.find_elements(:xpath, "//div[contains(@class,'OBR')]")
        load_time = "Under 5 seconds."
      rescue
        wait = Selenium::WebDriver::Wait.new(:timeout => 10)
        page_widgets += browser.find_elements(:xpath, "//div[contains(@class,'OBR')]")
        if page_widgets.length > 0
          load_time = "Under 5 seconds."
        else
          begin
            page_widgets = wait.until { browser.find_element(:xpath, "//div[contains(@class,'OUTBRAIN')]") }
            page_widgets = browser.find_elements(:xpath, "//div[contains(@class,'OUTBRAIN')]")
            page_widgets += browser.find_elements(:xpath, "//div[contains(@class,'OBR')]")
            load_time = "Under 15 seconds."
          rescue
            wait = Selenium::WebDriver::Wait.new(:timeout => 10)
            page_widgets += browser.find_elements(:xpath, "//div[contains(@class,'OBR')]")
            if page_widgets.length > 0
              load_time = "Under 15 seconds."
            else
              begin
                page_widgets = wait.until { browser.find_element(:xpath, "//div[contains(@class,'OUTBRAIN')]") }
                page_widgets = browser.find_elements(:xpath, "//div[contains(@class,'OUTBRAIN')]")
                page_widgets += browser.find_elements(:xpath, "//div[contains(@class,'OBR')]")
                load_time = "Under 25 seconds."
              rescue
                if page_widgets.length > 0
                  load_time = "Under 25 seconds."
                else
                  load_time = "Over 25 seconds."
                end
              end
            end
          end
        end
      end
      
      wait = Selenium::WebDriver::Wait.new(:timeout => 5)

      page_widgets.each do |widget|
        begin
          wait.until { widget.find_element(:xpath, "//li[contains(@class,'rec')]") }
        rescue
          begin
            wait.until { widget.find_element(:xpath, "//div[contains(@class,'rec')]") }
          rescue
            begin
              wait.until { widget.find_element(:xpath, "//a") }
            rescue
              nil
            end
          end
        end
      end

      har = proxy[driver_index].har
      #Iterate through har
      har.entries.each do |entry|
        if entry.request.url.include?('odb.outbrain.com' || 'hpr.outbrain.com')
          request = entry.request.query_string
          response = entry.response.content.text
          if entry.response.content.text == nil
            #add 'Response Error' to widget list
            request.each do |req_param|
              if req_param.has_value?('widgetJSId')
                bad_response = req_param['value']
                page_widget_ids[driver_index] += bad_response
                page_widget_ids[driver_index] += " (Response Error) \n"
              end
            end
          else
          found = false
          page_widgets.each do |widget|
            request.each do |req_param|
              #checking if the request has a widget ID equaling to widget's
              if req_param.has_value?(widget['data-widget-id'])
                found = true
                new_widget = Widget.new(widget, response, browser)
                cur_page.add_widget(new_widget)

                #print widget IDs for each platform
                page_widget_ids[driver_index] += new_widget.id
                if new_widget.tracking
                  page_widget_ids[driver_index] += " (Tracking)"
                end
                page_widget_ids[driver_index] += "\n"
 
                #Add platform to dupe widget
                if new_widget.duplicate
                  add_to_map(dupe_widgets, platform[driver_index], new_widget.id)
                end

                #Add platform to hidden widget
                if new_widget.hidden
                  add_to_map(hidden_widgets, platform[driver_index], new_widget.id)
                end

                #Add platform to serving issue widget
                if new_widget.serving
                  add_to_map(serving_iss_widgets, platform[driver_index], new_widget.id)
                end

                #Add platform to hidden ads widget
                if new_widget.hidden_ads
                  add_to_map(hidden_ads_widgets, platform[driver_index], new_widget.id)
                end

                #ignore API widgets
              elsif req_param.has_key?("format") && !req_param.has_value("html")
                api_widget = response.split('"widgetJsId":"')[1].split('"')[0]
                page_widget_ids[driver_index] += api_widget
                page_widget_ids[driver_index] += " (API) \n"
                found = true
              end


            end
          end

          #Widget requested but wiped from DOM
          if !found
              shady_widget = response.split('"widgetJsId":"')[1].split('"')[0]

              #add Shady to hidden
              if hidden_widgets.include?(shady_widget)
                add_plat = hidden_widgets[shady_widget] + ", " + platform[driver_index]
                hidden_widgets.store(shady_widget, add_plat)

              else
                hidden_widgets.store(shady_widget, platform[driver_index])

                #add 'Shady' to widget list
                page_widget_ids[driver_index] += shady_widget
                page_widget_ids[driver_index] += " (Shady) \n"
              end
          end
          end
          #taboola
        elsif entry.request.url.include?('taboola.com')
          if !taboola_found
            add_to_map(competitors, platform[driver_index], "Taboola")
            taboola_found = true
            if disqus_found
              add_to_map(competitors, platform[driver_index], "Disqus")
            end
          end
          #revcontent
        elsif entry.request.url.include?('revcontent.com')
          if !revcontent_found
            add_to_map(competitors, platform[driver_index], "Revcontent")
            revcontent_found = true
          end
          #zergnet
        elsif entry.request.url.include?('zergnet.com')
          if !zergnet_found
            add_to_map(competitors, platform[driver_index], "Zergnet")
            zergnet_found = true
          end
          #disqus
        elsif entry.request.url.include?('disqusads.com')
          if !disqus_found
            if taboola_found
              add_to_map(competitors, platform[driver_index], "Disqus")
            end
            disqus_found = true
          end
        end #filter for outbrain entries
      end #loop through entries
      
      #Add platform to widget load time
      add_to_map(load_times, platform[driver_index], load_time)

    rescue Net::ReadTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EINVAL
      begin
=begin
        drivers[driver_index].quit
        drivers[driver_index] = Selenium::WebDriver.for(:chrome, :desired_capabilities => caps[driver_index])
        if driver_index == 1
          drivers[1].manage.window.resize_to(768, 1024)
        end
        if driver_index == 2
          drivers[2].manage.window.resize_to(375, 667)
        end
=end
      browser.execute_script("window.stop();")
      rescue Errno::ECONNREFUSED, Net::ReadTimeout, Errno::ECONNRESET, Errno::EINVAL
        nil
      end
      page_loaded = false
      puts "Failed to load #{url} on #{platform[driver_index]}"
    end

    if !page_loaded
      page_widget_ids[driver_index] = "Page timeout"
    elsif cur_page.widgets.empty?
      page_widget_ids[driver_index] = "No widgets found"
    end

    driver_index += 1

  end #browser array loop

  #TODO Method for converting hashes to string
  #convert duplicates hash to string
  dupe_string = ""
  if dupe_widgets.empty? == true
    dupe_string = "None"
  else
    dupe_widgets.each do |wid|
      dupe_string += wid[0] + " (" + wid[1] + ")\n"
    end
  end

  #convert hidden hash to string
  hidden_string = ""
  if hidden_widgets.empty? == true
    hidden_string = "None"
  else
    hidden_widgets.each do |wid|
      hidden_string += wid[0] + " (" + wid[1] + ")\n"
    end
  end

  #convert serving issue hash to string
  serv_iss_string = ""
  if serv_iss_widgets.empty? == true
    serv_iss_string = "None"
  else
    serv_iss_widgets.each do |wid|
      serv_iss_string += wid[0] + " (" + wid[1] + ")\n"
    end
  end

  #convert hidden ads hash to string
  hidden_ads_string = ""
  if hidden_ads_widgets.empty? == true
    hidden_ads_string = "None"
  else
    hidden_ads_widgets.each do |wid|
      hidden_ads_string += wid[0] + " (" + wid[1] + ")\n"
    end
  end

  #convert load times hash to string
  load_times_string = ""
  load_times.each do |wid|
    load_times_string += wid[0] + " (" + wid[1] + ")\n"
  end

  #convert competitor widgets hash to string
  competitor_widgets_string = ""
  if competitors.empty? == true
    competitor_widgets_string = "None"
  else
    competitors.each do |wid|
      competitor_widgets_string += wid[0] + " (" + wid[1] + ")\n"
    end
  end

  row_array = [dupe_string, hidden_string, serv_iss_string, hidden_ads_string, load_times_string, competitor_widgets_string, page_widget_ids[0], page_widget_ids[1], page_widget_ids[2]]
  results_array << row_array


end #url array loop

###Print results to sheet
row = 51

urls.each do
  9.times do |column|
    ws[row, column + 6] = results_array[row - 51][column]
  end
  row += 1
end

ws[2, 15] = Date.today.to_s
ws.save
###end Print

proxy.each do |prox|
  prox.close
end

drivers.each do |driver|
  driver.quit
end