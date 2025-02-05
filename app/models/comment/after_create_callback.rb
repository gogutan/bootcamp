# frozen_string_literal: true

class Comment::AfterCreateCallback
  def after_commit(comment)
    if comment.commentable.class.include?(Watchable)
      create_watch(comment)
      notify_to_watching_user(comment)
    elsif comment.sender != comment.receiver
      notify_comment(comment)
    end

    if comment.commentable.instance_of?(Talk)
      notify_to_admins(comment)
      notify_to_chat(comment) unless comment.sender.admin?
      update_unreplied(comment)
    end

    return unless comment.commentable.instance_of?(Product)

    comment.commentable.update_last_commented_at(comment)
    comment.commentable.update_commented_at(comment)
    delete_product_cache(comment.commentable.id)
    delete_assigned_and_unreplied_product_count_cache(comment)
  end

  private

  def notify_comment(comment)
    commentable_path = Rails.application.routes.url_helpers.polymorphic_path(comment.commentable)
    NotificationFacade.came_comment(
      comment,
      comment.receiver,
      "相談部屋で#{comment.sender.login_name}さんからコメントがありました。",
      "#{commentable_path}#latest-comment"
    )
  end

  def notify_to_watching_user(comment)
    watchable = comment.commentable
    mention_user_ids = comment.new_mention_users.ids

    return unless watchable.try(:watched?)

    watcher_ids = watchable.watches.pluck(:user_id)
    watcher_ids.each do |watcher_id|
      next unless watcher_id != comment.sender.id && !mention_user_ids.include?(watcher_id)

      watcher = User.find_by(id: watcher_id)
      sender = comment.sender

      ActivityDelivery.with(
        watchable: watchable,
        receiver: watcher,
        comment: comment,
        sender: sender
      ).notify(:watching_notification)
    end
  end

  def create_watch(comment)
    watchable = comment.commentable

    return if watchable.watches.pluck(:user_id).include?(comment.sender.id)

    @watch = Watch.new(
      user: comment.sender,
      watchable: watchable
    )
    @watch.save!
  end

  def delete_product_cache(product_id)
    Rails.cache.delete "/model/product/#{product_id}/last_commented_user"
  end

  def delete_assigned_and_unreplied_product_count_cache(comment)
    product = comment.commentable

    return unless product.checker_id.present? && product.replied_status_changed?(comment.previous&.user_id, comment.user_id)

    Cache.delete_self_assigned_no_replied_product_count(product.checker_id)
  end

  def notify_to_admins(comment)
    User.admins.each do |admin_user|
      next if comment.sender == admin_user

      commentable_path = Rails.application.routes.url_helpers.polymorphic_path(comment.commentable)
      NotificationFacade.came_comment(
        comment,
        admin_user,
        "#{comment.commentable.user.login_name}さんの相談部屋で#{comment.sender.login_name}さんからコメントが届きました。",
        "#{commentable_path}#latest-comment"
      )
    end
  end

  def update_unreplied(comment)
    unreplied = !comment.user.admin
    comment.commentable.update!(unreplied: unreplied)
  end

  def notify_to_chat(comment)
    ChatNotifier.message(<<~TEXT, webhook_url: ENV['DISCORD_ADMIN_WEBHOOK_URL'])
      相談部屋にて#{comment.user.login_name}さんからコメントがありました。
      本文： #{comment.description}
      URL： https://bootcamp.fjord.jp/talks/#{comment.commentable_id}#latest-comment
    TEXT
  end
end
