require 'securerandom'

class RemoteUserAuthMiddleware

  DefaultUserHeaderName = "Remote-User"
  DefaultEmailHeaderName = "Remote-Email"
  DefaultGroupsHeaderName = "Remote-Groups"
  # if the header specified by user_header_name is provided in the
  # request, treat the value of that header as a username, and log in as that
  # user, creating if necessary.
  #
  # This middleware can also be configured to detect headers containing the
  # user's email, and comma separated group membership (along with a group name
  # that signifies the created user should be an admin) during the user
  # creation phase.
  #
  def initialize(app, user_header_name = nil, email_header_name = nil, groups_header_name = nil, admin_group = nil, warden_scope = :user)
    @app = app
    @user_header_name = (user_header_name || DefaultUserHeaderName).gsub("-", "_").upcase
    @email_header_name = (email_header_name || DefaultEmailHeaderName).gsub("-", "_").upcase
    @groups_header_name = (groups_header_name || DefaultGroupsHeaderName).gsub("-", "_").upcase
    @admin_group = admin_group
    @warden_scope = warden_scope
  end

  def call(env)
    begin
      username = env['HTTP_' + @user_header_name]
      # do nothing if no remote-user is presented
      if not username.blank?
        user = User.find_or_create_by!(username: username) do |u|
          u.requires_no_invitation_code!

          # needed for devise validations
          u.password = SecureRandom.urlsafe_base64(32)
          u.email = env['HTTP_' + @email_header_name] || "#{username}@remoteuser.auth"
          # we may want this configurable in the future
          group_delimeter = ","
          u.admin = !!@admin_group && env['HTTP_' + @groups_header_name].split(group_delimeter).include?(@admin_group)
        end

        warden = env['warden']
        # perform login unless user is already logged in
        unless warden.user(@warden_scope) == user
          warden.set_user(user, { :scope => @warden_scope })
        end
      end
    rescue
    end

    @app.call(env)
  end
end


