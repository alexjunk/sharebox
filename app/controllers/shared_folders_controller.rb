## 
# manage folder sharing within the sharebox site

class SharedFoldersController < ApplicationController

  before_action :authenticate_user!
  
  ##
  # Show the control panel allowing to manage all share emails associated to a folder<br>
  # Via the control panel, the folder owner can :<br>
  # - display satisfaction answers by clicking on the email of the user who recorded the satisfaction<br>
  # - remove shares one by one, unless a satisfaction answer was recorded on the share<br>
  # - send automatic emails<br>
  # For each share email, the control panel display the number of clicks on the shared assets<br>
  # The form of the user email can be different depending on the 'shared' folder configuration<br>
  # You can have many different folder configurations :<br>
  # - folder with files but without any poll associated > file available type mel<br>
  # - folder with files and with a poll associated > file+satisfaction type mel<br>
  # - folder without files and with a poll associated > satisfaction type mel<br>
  # - one of the above with satisfaction answer(s) > no email for users who already recorded their satisfaction<br>
  # - folder with or without files, with satisfaction answer(s) and with no poll associated<br>
  # - folder with or without files and with satisfaction answers(s) on a poll which was removed and replaced by another one<br>
  # - folder with or without files and with satisfaction answer(s) on different polls<br>
  # You cannot send email from an empty folder without any poll associated
  def show
    # Happens only when a mail is sent 
    if params[:share_email]
      @folder = Folder.find_by_id(params[:id])
      @shared_files = Asset.where("folder_id = "+params[:id])
      if @shared_files.count == 0 && !@folder.is_polled?
        t1 = "Vous ne pouvez pas envoyer de mel !"
        t2 = "D'une part, le répertoire partagé est vide"
        t3 = "D'autre part, le répertoire partagé n'est pas lié à une enquête satisfaction"
        t4 = "Chargez donc un livrable ou associez au répertoire une enquête satisfaction"
        flash[:notice] = "#{t1}<br>#{t2}<br>#{t3}<br>#{t4}"
      else
        flash[:notice] = SHARED_FOLDERS_MSG["mail_sent_to"] + params[:share_email]
        InformUserJob.perform_now(current_user,params[:share_email],params[:id])
      end
      redirect_to shared_folder_path(params[:id])
    end
    # everybody can access to the sharing list on an existing folder
    # this is absolutely not a secret thing
    @shared_folders = SharedFolder.where("folder_id = "+params[:id]) 
    @current_folder = Folder.find(params[:id])
    @satisfactions = Satisfaction.where(folder_id: params[:id])
  end
  
  # This method is only used when MANUALLY following the route /complete_suid<br>
  # it does the following tasks :<br>
  # - send to the admin a list with all the unregistered emails which benefited from shared access to a folder<br>
  # - manually launch the set_admin method (cf user model)<br>
  def complete_suid
    current_user.complete_suid
    if current_user.set_admin
      flash[:notice] = "#{current_user.email} root/admin"
    end
    redirect_to root_url
  end

  ##
  # Show the sharing form<br>
  # When a folder is shared to a user, you must give at least one email address or more but separated by a ","
  def new
    @to_be_shared_folder = Folder.find_by_id(params[:id])
    if !current_user.has_ownership?(@to_be_shared_folder)
      flash[:notice] = SHARED_FOLDERS_MSG["inexisting_folder"]
      redirect_to root_url
    else
      @shared_folder = current_user.shared_folders.new
      @current_folder = @to_be_shared_folder.parent
    end
  end

  ##
  # Saves the shared emails in the database<br>
  # you cannot share to yourself a folder you own<br>
  # the method verify if shared emails are already registered in the database for the specified folder (folder_id)<br>
  # the sharing activity details are emailed to the admin (cf variable admin_mel as declared in the main section of config.yml)<br>
  def create
  
    flash[:notice]=""
    saved_shares=""
    emails=params[:shared_folder][:share_email].delete(" ")

    if emails == ""
      flash[:notice]= SHARED_FOLDERS_MSG["email_needed"]
      redirect_to new_share_on_folder_path(params[:shared_folder][:folder_id])
    else
      email_addresses = emails.split(",")
      email_addresses.each do |email_address|
        email_address=email_address.delete(' ')
        if email_address == current_user.email
          flash[:notice] = "#{flash[:notice]} #{SHARED_FOLDERS_MSG["you_are_folder_owner"]}<br>"
        else
          # is the email_address already in the folder's shares ?
          if current_user.shared_folders.find_by_share_email_and_folder_id(email_address,params[:shared_folder][:folder_id])
            flash[:notice] = "#{flash[:notice]} #{SHARED_FOLDERS_MSG["already_shared_to"]} #{email_address}<br>"
          else
            @shared_folder = current_user.shared_folders.new(shared_folder_params)
            @shared_folder.share_email = email_address
            # We search if the email exist in the user table
            # if not, we'll have to update the share_user_id field after registration
            share_user = User.find_by_email(email_address)
            @shared_folder.share_user_id = share_user.id if share_user
            if @shared_folder.save
              a = "#{SHARED_FOLDERS_MSG["shared_to"]} #{email_address}"
              flash[:notice] = "#{flash[:notice]} #{a}<br>"
              saved_shares = "#{saved_shares} #{a}<br>"
            else
              flash[:notice] = "#{flash[:notice]} #{SHARED_FOLDERS_MSG["unable_share_for"]} #{email_address}<br>"
            end
          end
        end
      end
      # we leave the sharing form (app/views/shared_folders/_form.html.erb)
      # the id of the folder that we just shared is given by : params[:shared_folders][:folder_id]
      @folder = current_user.folders.find(params[:shared_folder][:folder_id])
      if saved_shares != ""
        if @folder.parent_id
          redirect_to folder_path(@folder.parent_id)
        else
          redirect_to root_url
        end
      else
        redirect_to new_share_on_folder_path(params[:shared_folder][:folder_id])
      end
    end
    
    # if new shares were successfully saved, then we inform the admin
    if saved_shares != ""
      mel_to_admin = "#{SHARED_FOLDERS_MSG["folder"]} #{params[:shared_folder][:folder_id]}<br>"
      mel_to_admin = "#{mel_to_admin}<b>[#{@folder.name.html_safe}]</b><br>#{saved_shares}"
      InformAdminJob.perform_now(current_user,mel_to_admin)
      # alternative not using jobs
      #UserMailer.inform_admin(current_user,mel_to_admin).deliver_now
    end
    
  end

  ##
  # Delete specific share(s) within the show view<br>
  # After deletion, we redirect to root view if all shares were deleted
  def destroy
    if !params[:ids]
      flash[:notice] = SHARED_FOLDERS_MSG["no_share_selected"]
    else
      params[:ids].each do |id|
        SharedFolder.find_by_id(id).destroy
      end
      flash[:notice] = SHARED_FOLDERS_MSG["shares_destroyed"]
    end

    if !SharedFolder.find_by_folder_id(params[:id])
      redirect_to root_url
    else
      redirect_to shared_folder_path(params[:id])
    end
  end

  private
    def shared_folder_params
      params.require(:shared_folder).permit(:share_email, :share_user_id, :folder_id, :message)
    end
  
 end