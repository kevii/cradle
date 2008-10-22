class SyntheticController < ApplicationController
  include SyntheticHelper
  
  def define_internal_structure
    synthetic_class = verify_domain(params[:domain])['Synthetic']
    case params[:type]
      when "define"
        if params[:from] == "creation"
          structure = [params[:original_id].to_i]
        elsif params[:from] == "modification"
          structure = get_structure(:ref_id=>params[:original_id].to_i)
        end
      when "modify", "new", "delete"
        ids, chars = get_ids_and_chars(params.update({:domain=>params[:domain]}))
    end
    render :update do |page|
      page["synthetic_struct"].replace :partial=>"synthetic/show_internal_structure",
                                       :object=> structure,
                                       :locals=>{:original_id=>params[:original_id], :from=>params[:from], :domain=>params[:domain]}
    end
  end
  
  private
  def get_structure(option)
    option[:meta_id] = 0 if option[:meta_id].blank?
    option[:meta_id] ==0 ? structure = [option[:ref_id]] : structure = ['meta']
    temp_array = option[:synthetic_class].constantize.find(:first, :conditions=>["sth_ref_id=? and sth_meta_id=?", option[:ref_id], option[:meta_id]]).map{|item| item.delete('-')}
    temp_array.each{|item|
      if item =~ /^\d+$/
        structure << item.to_i
      elsif item =~ /^meta_(\d+)$/
        structure << get_structure(:ref_id=>option[:ref_id], :meta_id=>$1.to_i)
      end
    }
    return structure
  end
end