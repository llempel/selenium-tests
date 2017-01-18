require 'selenium/webdriver'
require 'browsermob/proxy'
require 'google_drive'
require_relative './Page.rb'
require_relative './Widget.rb'


#TODO TIMEOUTS
#TODO POSITION SHEETS

###BrowserMob
server = BrowserMob::Proxy::Server.new('/Users/canglin/BrowserMob/bin/browsermob-proxy') #=> #<BrowserMob::Proxy::Server:0x000001022c6ea8 ...>

server.start

proxy = server.create_proxy #=> #<BrowserMob::Proxy::Client:0x0000010224bdc0 ...>
###end BrowserMob


###Selenium Drivers
caps = Selenium::WebDriver::Remote::Capabilities.chrome(:proxy => proxy.selenium_proxy)

drivers = [Selenium::WebDriver.for(:chrome, :desired_capabilities => caps),
           Selenium::WebDriver.for(:chrome, :desired_capabilities => caps, :switches => %w[--user-agent=Mozilla/5.0(iPad; U; CPU iPhone OS 3_2 like Mac OS X; en-us) AppleWebKit/531.21.10 (KHTML, like Gecko) Version/4.0.4 Mobile/7B314 Safari/531.21.10]),
           Selenium::WebDriver.for(:chrome, :desired_capabilities => caps, :switches => %w[--user-agent=Mozilla/5.0 (iPhone; CPU iPhone OS 9_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13B143 Safari/601.1])]

platform = ['Desktop', 'Tablet', 'Mobile']

drivers[1].manage.window.resize_to(768, 1024)
drivers[2].manage.window.resize_to(375, 667)
###end Selenium Drivers


###Sheets integration
#TODO OAUTH
session = GoogleDrive::Session.from_config('config.json')
ws = session.spreadsheet_by_key('11SNfwSMrBjLaaE9qtS1q7hrRaDNIqiHFo5cmCdVqj2E').worksheets[0]

urls = []

results_array = []
row_array = []

#Create array from sheet URL list

(2..4).each do |row|
  urls << ws[row, 1]
end
###end Sheets integration


#Loop through each URL
urls.each do |url|
  dupe_widgets = Hash.new
  hidden_widgets = Hash.new
  serv_iss_widgets = Hash.new
  page_widget_ids = ["", "", ""]
  driver_index = 0


  #Loop through each platform
  drivers.each do |browser|

    cur_page = Page.new
    page_loaded = true
    page_widgets = []

    #check for MSN
    if url.include?('msn.com')
      if driver_index == 2
        url = url + '?fdhead=m-al-ar-ob'
      else
        url = url + '?fdhead=al-ar-obvnext'
      end
    end

    #Instantiate new proxy file
    proxy.new_har(:capture_content => true)


    begin
      browser.get(url)
      puts "Testing #{url} on #{platform[driver_index]}"
    rescue Net::ReadTimeout
      page_loaded = false
      puts "Failed to load #{url} on #{platform[driver_index]}"
      next
    end

    if !page_loaded
      page_widget_ids[driver_index] += "Page timeout"
      puts "page load test is working"
      #If tests pause, set the browser to close & relaunch here
    end

    if page_loaded
      har = proxy.har

      wait = Selenium::WebDriver::Wait.new(:timeout => 30)
      wait.until {
        #Get divs from page to compare
        #page_widgets = browser.find_elements(:class, 'OUTBRAIN')
        page_widgets = browser.find_elements(:xpath, "//div[contains(@class,'OUTBRAIN')]")
        page_widgets += browser.find_elements(:xpath, "//div[contains(@class,'OBR')]")
      }

      #Iterate through har
      har.entries.each do |entry|
        if entry.request.url.include?('odb.outbrain.com' || 'hpr.outbrain.com')
          request = entry.request.query_string
          response = entry.response.content.text
          found = false
          page_widgets.each do |widget|
            request.each do |req_param|
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

=begin #TODO Method for adding platform
              def problem_loop(widg_status, hashname, driver_index, new_widget, platform)
                do
                if new_widget.widg_status
                  if hashname.include?(new_widget.id)
                    add_plat = hashname[new_widget.id] + ', ' + platform[driver_index]
                    hashname.store(new_widget.id, add_plat)
                  else
                    hashname.store(new_widget.id, platform[driver_index])
                  end
                end
              end
              problem_loop(duplicate, dupe_widgets, driver_index, new_widget, platform)
              problem_loop(hidden, hidden_widgets, driver_index, new_widget, platform)
              problem_loop(serving, serv_iss_widgets, driver_index, new_widget, platform)
=end

                #Add platform to dupe widget
                if new_widget.duplicate
                  if dupe_widgets.include?(new_widget.id)
                    add_plat = dupe_widgets[new_widget.id] + ', ' + platform[driver_index]
                    dupe_widgets.store(new_widget.id, add_plat)
                  else
                    dupe_widgets.store(new_widget.id, platform[driver_index])
                  end
                end

                #Add platform to hidden widget
                if new_widget.hidden
                  if hidden_widgets.include?(new_widget.id)
                    add_plat = hidden_widgets[new_widget.id] + ', ' + platform[driver_index]
                    hidden_widgets.store(new_widget.id, add_plat)
                  else
                    hidden_widgets.store(new_widget.id, platform[driver_index])
                  end
                end

                #Add platform to serving issue widget
                if new_widget.serving
                  if serv_iss_widgets.include?(new_widget.id)
                    add_plat = serv_iss_widgets[new_widget.id] + ', ' + platform[driver_index]
                    serv_iss_widgets.store(new_widget.id, add_plat)
                  else
                    serv_iss_widgets.store(new_widget.id, platform[driver_index])
                  end
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
        end #filter for outbrain entries
      end #loop through entries
    end #page_loaded


    if cur_page.widgets.empty?
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

  row_array = [dupe_string, hidden_string, serv_iss_string, page_widget_ids[0], page_widget_ids[1], page_widget_ids[2]]
  results_array << row_array


end #url array loop

puts results_array

###Print results to sheet
row = 2

urls.each do
  6.times do |column|
    ws[row, column + 6] = results_array[row - 2][column]
  end
  row += 1
end

ws.save
###end Print

proxy.close
drivers.each do |driver|
  driver.quit
end