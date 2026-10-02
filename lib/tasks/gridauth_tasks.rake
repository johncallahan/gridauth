namespace :gridauth do
  desc "Revoke all grid cards for a user (e.g. a lost card): bin/rails \"gridauth:revoke[user@example.com]\""
  task :revoke, [ :user ] => :environment do |_task, args|
    abort "Usage: bin/rails \"gridauth:revoke[<user id or #{Gridauth.config.user_label_attribute}>]\"" if args[:user].blank?

    users = Gridauth.user_class
    user = users.find_by(id: args[:user]) || users.find_by(Gridauth.config.user_label_attribute => args[:user])
    abort "No user found for #{args[:user].inspect}" unless user

    user.revoke_grid_cards!
    puts "Revoked grid cards for #{args[:user]}. They can sign in with their password and set up a new card."
  end

  desc "List active grid cards that are due for rotation"
  task due: :environment do
    Gridauth::GridCard.active.includes(:user).find_each do |card|
      puts "#{card.serial}\tuser #{card.user_id}\tactivated #{card.activated_at.to_date}\tuses #{card.use_count}" if card.rotation_due?
    end
  end
end
