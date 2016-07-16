require "nokogiri"
require "open-uri"

@tdcc_url = "http://www.tdcc.com.tw/smWeb/QryStock.jsp"
@exchange_list_url = "http://isin.twse.com.tw/isin/C_public.jsp?strMode=2"
@otc_list_url = "http://isin.twse.com.tw/isin/C_public.jsp?strMode=4"

module Tdcc
  def self.fetch_all_stock_number
    exchange = fetch_list(@exchange_list_url)
    otc = fetch_list(@otc_list_url)
    # emerging = fetch_list(@emerging_list_url)
    return [*exchange, *otc]
  end

  def self.fetch_all_dates
      # return a list of all the dates
      dates = []
      open_url = open(@tdcc_url)
      date_tmp = Nokogiri::HTML(open_url).css("option")

      date_tmp.each do |date_t|
          dates << date_t.inner_text
      end

      return dates
  end

  def self.fetch_list(target_url)
    result_list = []
    web_data = Nokogiri::HTML(open(target_url))
    trs = web_data.css("tr")
    trs.each do |tr|
      if /^\d{4}\s/.match(tr.inner_text)
        result_list << tr.inner_text[0, 4]
      end
    end
    return result_list
  end
end
