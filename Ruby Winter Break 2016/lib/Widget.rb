require "selenium/webdriver"
require "browsermob/proxy"

class Widget

  attr_accessor :id
  attr_accessor :duplicate
  attr_accessor :hidden
  attr_accessor :serving
  attr_accessor :tracking
  attr_accessor :hidden_ads

  @id = ""
  @tracking = false
  @hidden = false
  @serving = false
  @duplicate = false
  @hidden_ads = false

  def initialize(div, response, browser)
    @page_div = div
    @network_response = response
    @browser = browser
    @id = @page_div['data-widget-id']
    find_tracking
    context_rule
    find_hidden
    serving_issue
    single_ad_serving_issue
  end

  def context_rule
    if !@network_response.include?(@id) || @network_response.include?('CR' + @id)
      @id = @network_response.split('"widgetJsId":"')[1].split('"')[0]
      if !@tracking
        @page_div = @page_div.find_element(:xpath, "//div[contains(@class, '#{@id}')]")
      end
    end
  end

  def find_location
    #TODO
  end

  def find_tracking
    @tracking = @network_response.include?('tracking":true')||@network_response.include?('stopWidget":true')
  end

  def find_hidden
    @hidden = !@page_div.displayed? && !@tracking
  end

  def serving_issue
    @serving = !@tracking && @network_response.include?('org":0, "pad":0')
  end

  def single_ad_serving_issue
    temp = @network_response.split("\"org\":")
    total_recs = temp[1].split(",")[0].to_i + temp[1].split(",\"pad\":")[1].split(",")[0].to_i
    recs = @page_div.find_elements(:xpath, "//div[contains(@class,'#{@id}')]//li[contains(@class,'ob-recIdx-')]|//div[contains(@class,'#{@id}')]//div[@class=\"ob_container_recs\"]//a")
    recs.each do |rec|
      if !rec.displayed?
        @hidden_ads = true
      end
    end
    @hidden_ads = @hidden_ads || (total_recs != recs.length)
  end


end