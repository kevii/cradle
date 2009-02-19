module MaintenanceMode
protected
  def disabled?
    maintfile = RAILS_ROOT + "/public/system/maintenance.html"
    if FileTest::exist?(maintfile)
      send_file maintfile, :type => 'text/html; charset=utf-8', :disposition => 'inline'
      @performed_render = true
    end
  end
end