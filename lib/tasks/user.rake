namespace :user do

  # rake user:downgrade_expired
  task :downgrade_expired => :environment do
    User.pro_only.yearly.not_forever.joins(:payments).having("MAX(payments.date) < ?", 367.days.ago).group("users.id").each do |user|
      user.update(plan: "Free")
      UserMailer.downgraded(user).deliver_later
    end

    User.pro_only.monthly.not_forever.joins(:payments).having("MAX(payments.date) < ?", 32.days.ago).group("users.id").each do |user|
      user.update(plan: "Free")
      UserMailer.downgraded(user).deliver_later
    end
  end

  task :downgrade_gumroad_expired => :environment do
    User.gumroad_only.pro_only.yearly.not_forever.joins(:payments).having("MAX(payments.date) < ?", 367.days.ago).group("users.id").each do |user|
      user.update(plan: "Free")
      UserMailer.downgraded(user).deliver_later
    end

    User.gumroad_only.pro_only.monthly.not_forever.joins(:payments).having("MAX(payments.date) < ?", 32.days.ago).group("users.id").each do |user|
      user.update(plan: "Free")
      UserMailer.downgraded(user).deliver_later
    end
  end 

  task :downgrade_paypal_expired => :environment do
    User.paypal_only.pro_only.yearly.not_forever.joins(:payments).having("MAX(payments.date) < ?", 367.days.ago).group("users.id").each do |user|
      user.update(plan: "Free")
      UserMailer.downgraded(user).deliver_later
    end

    User.paypal_only.pro_only.monthly.not_forever.joins(:payments).having("MAX(payments.date) < ?", 32.days.ago).group("users.id").each do |user|
      user.update(plan: "Free")
      UserMailer.downgraded(user).deliver_later
    end
  end  

end