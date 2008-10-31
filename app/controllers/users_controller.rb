class UsersController < ApplicationController
  before_filter :authorize, :except => :login
  before_filter :authorize_admin, :only => [ :list_users, :add_user, :delete_user, :merge_user]
  before_filter :set_current_user

  def index
    redirect_to :action=>'login'  
  end
  
  def login
    session[:user_id] = nil
    if request.post?
      user = User.authenticate(params[:name], params[:password])
      if user
        session[:user_id] = user.id
        redirect_to(:controller=>:jp, :action=>:index)
      else
        flash[:notice_err] = "<ul><li>Invalid user/password combination.</li></ul>"
      end
    end
  end
  
  def logout
    session[:user_id] = nil
    ['10_tagging_state', '11_log', '12_created_by', '13_modified_by', '14_updated_at',
     '101_sth_tagging_state', '102_sth_log', '103_sth_modified_by', '104_sth_updated_at'].each{|item| session[:jp_section_list].delete(item)}
    redirect_to(:controller=>:jp, :action=>:index)
  end
  
  def list_users
    @all_users = User.find(:all)
  end

  def add_user
    @user = User.new(params[:user])
    if request.post?
      begin
        @user.save!
      rescue
      else
        flash[:notice] = "<ul><li>User [#{@user.name}] created.</li></ul>"
        redirect_to(:action => :list_users)
      end
    end
  end

  def delete_user
    begin
      @user=User.find_by_id(params[:id])
      @user.destroy
    rescue Exception => e
      flash[:notice_err] = "<ul><li>#{e.message}</li></ul>"
    else
      if @user.errors.blank?
        flash[:notice] = "<ul><li>User #{@user.name} deleted!</li></ul>"
      else
        flash[:notice_err] = "<ul><li>"+@user.errors['base']+"</li></ul>"
      end
    end
    redirect_to(:action => :list_users)
  end

  def merge_user
    if params[:old_user].blank? or params[:merge_user].blank?
      flash[:notice_err] = "<ul><li>Please specify both users in the merge action!</li></ul>"
      redirect_to(:action => :list_users)
      return
    end
    ActiveRecord::Base.connection.execute("update jp_lexemes set created_by=#{params[:merge_user].to_i} where created_by=#{params[:old_user].to_i};")
    ActiveRecord::Base.connection.execute("update jp_lexemes set modified_by=#{params[:merge_user].to_i} where modified_by=#{params[:old_user].to_i};")
    ActiveRecord::Base.connection.execute("update jp_synthetics set modified_by=#{params[:merge_user].to_i} where modified_by=#{params[:old_user].to_i};")
######## jia-l leave for cn
#    ActiveRecord::Base.connection.execute("update cn_lexemes set created_by=#{params[:merge_user].to_i} where created_by=#{params[:old_user].to_i};")
#    ActiveRecord::Base.connection.execute("update cn_lexemes set modified_by=#{params[:merge_user].to_i} where modified_by=#{params[:old_user].to_i};")
#    ActiveRecord::Base.connection.execute("update cn_synthetics set modified_by=#{params[:merge_user].to_i} where modified_by=#{params[:old_user].to_i};")
    flash[:notice] = "<ul><li>Merge user succeeded!</li></ul>"
    redirect_to(:action => :list_users)
  end

  def chg_pwd
    @user =  User.find_by_id(session[:user_id])
    if request.post?
        if @user == User.authenticate(@user.name, params[:password][:now])
              @user.password = params[:user][:password]
              @user.password_confirmation = params[:user][:password_confirmation]
              begin
                @user.save!
              rescue
              else
                flash[:notice] = "<ul><li>Password changed.</li></ul>"
                redirect_to(:action => :chg_pwd)
              end
        else
          @user.errors.add_to_base("Wrong current password!")
        end
    end
  end
  
  private
  def set_current_user
    Thread.current["user_id"] = session[:user_id]
  end

end