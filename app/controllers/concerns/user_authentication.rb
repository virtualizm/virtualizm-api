module Concerns
  module UserAuthentication

    def current_user
      return @current_user if defined?(@current_user)
      @current_user = User.find_by id: session['user_id']
    end

  end
end
