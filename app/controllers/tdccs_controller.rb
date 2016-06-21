class TdccsController < ApplicationController
    def index
    end
    
    def testxxx
        CrawlTdccDataService.new.fetch_all_data
        redirect_to tdccs_path
    end
end
