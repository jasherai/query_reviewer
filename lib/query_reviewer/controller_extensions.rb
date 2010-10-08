require File.join(File.dirname(__FILE__), "views", "query_review_box_helper")

require "action_view"
module QueryReviewer
  module ControllerExtensions
    class QueryViewBase < ActionView::Base
      include QueryReviewer::Views::QueryReviewBoxHelper
    end

    def self.included(base)
      base.alias_method_chain :process_action, :query_review if QueryReviewer::CONFIGURATION["inject_view"]
      base.alias_method_chain :process, :query_review
      base.helper_method :query_review_output
    end

    def query_review_output(type, total_time = nil)
      faux_view = QueryViewBase.new([File.join(File.dirname(__FILE__), "views")], {}, self)
      queries = Thread.current["queries"]
      queries.analyze!
      faux_view.instance_variable_set("@queries", queries)
      faux_view.instance_variable_set("@total_time", total_time)
      
      if type == :ajax
        js = faux_view.render(:partial => "/box_ajax.js")
      elsif type == :log
        txt = faux_view.render(:partial => "/log_review")
      else
        html = faux_view.render(:partial => "/box")
      end
    end

    def add_query_output_to_view(total_time)
      if request.xhr?
        if cookies["query_review_enabled"]
          if !response.content_type || response.content_type.include?("text/html")
            response.body += "<script type=\"text/javascript\">"+query_review_output(:ajax, total_time)+"</script>"
          elsif response.content_type && response.content_type.include?("text/javascript")
            response.body += ";\n"+query_review_output(:ajax, total_time)
          end
        end
      else
        if response.body.is_a?(String) && response.body.match(/<\/body>/i) && Thread.current["queries"]
          idx = (response.body =~ /<\/body>/i)
          html = query_review_output(nil, total_time)
          response.body.insert(idx, html)
        end
      end
    end

    def process_action_with_query_review(*args)
      Thread.current["query_reviewer_enabled"] = cookies["query_review_enabled"]
      t1 = Time.now
      r = process_action_without_query_review(*args)
      t2 = Time.now
      add_query_output_to_view(t2 - t1)
      QueryReviewer.logger.info(query_review_output(:log, t2 - t1))
      r
    end

    def process_with_query_review(*args)
      Thread.current["queries"] = SqlQueryCollection.new
      process_without_query_review(*args)
    end
  end
end
