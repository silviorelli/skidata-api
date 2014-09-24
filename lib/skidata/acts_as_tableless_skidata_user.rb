module Skidata
  module ActsAsTablelessSkidataUser
    extend ActiveSupport::Concern

    included do
    end

    module ClassMethods
      def acts_as_tableless_skidata_user(options = {})
        include Skidata::ActsAsTablelessSkidataUser::LocalInstanceMethods
      end

      def load_from_api id, validation_cookie
        client = Skidata.client

        api_user_response = client.get_user id, validation_cookie

        if api_user_response.code.to_i == 200
          user_hash = ActiveSupport::JSON.decode api_user_response.body

          record = new(:id => user_hash['UserID'],
                       :email => user_hash['EmailAddress'],
                       :name => user_hash['DisplayName'],
                       :leaderboard_overall_position => user_hash['LeaderboardPosition']['OverallPosition'],
                       :season_points_earned => user_hash['CurrentPoints']['SeasonPointsEarned'])

          record.set_points validation_cookie

          return record
        else
          raise ActiveRecord::RecordNotFound
        end

      end
    end

    module LocalInstanceMethods
      def authenticate_user
        # don't need to run true api validation if something else is wrong
        return unless self.errors.empty?

        client = Skidata.client
        login_type = client.get_login_type self.email
        validation_response = client.validate self.email, login_type, self.password

        validation_response = ActiveSupport::JSON.decode validation_response.body

        if validation_response.has_key?("userIsVerified") && validation_response['userIsVerified']
          self.id = validation_response['userId']
        else
          if(validation_response.has_key?("Message"))
            errors.add(:email, validation_response['Message'])
          else
            errors.add(:email, "Invalid username or password.")
          end
        end
      end

      def set_points validation_cookie
        self.points = Skidata.client.get_points self.id, validation_cookie
      end
    end
  end
end

ActiveRecord::Base.send :include, Skidata::ActsAsTablelessSkidataUser