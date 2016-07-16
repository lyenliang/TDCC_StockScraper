require "nokogiri"
require "open-uri"

module Tdcc
  def self.fetch_all_stock_number
    exchange = fetch_list("http://isin.twse.com.tw/isin/C_public.jsp?strMode=2")
    otc = fetch_list("http://isin.twse.com.tw/isin/C_public.jsp?strMode=4")
    # emerging = fetch_list(@emerging_list_url)
    return [*exchange, *otc]
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
