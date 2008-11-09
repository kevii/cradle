module ApplicationHelper
  def button_to_remote(name, options = {}, html_options = {})
    cradle_button_to_function(name, remote_function(options), html_options)
  end

  def periodically_call_remote(options = {})
    variable = options[:variable] ||= 'poller'
    frequency = options[:frequency] ||= 10
    code = "#{variable} = new PeriodicalExecuter(function(){#{remote_function(options)}}, #{frequency})"
    javascript_tag(code)
  end 

  private
  def cradle_button_to_function(name, function, html_options = {})
    html_options.symbolize_keys!
    tag(:input, html_options.merge({
    :type => "button", :value => name,
    :onclick => (html_options[:onclick] ? "#{html_options[:onclick]}; " : "") + "#{function};"
    }))
  end
end
