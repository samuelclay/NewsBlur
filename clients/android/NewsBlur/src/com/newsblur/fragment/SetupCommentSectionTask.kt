package com.newsblur.fragment

import android.content.Context
import android.content.Intent
import android.text.TextUtils
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.fragment.app.DialogFragment
import androidx.fragment.app.FragmentManager
import androidx.lifecycle.lifecycleScope
import com.google.android.material.imageview.ShapeableImageView
import com.newsblur.R
import com.newsblur.activity.Profile
import com.newsblur.domain.Comment
import com.newsblur.domain.Story
import com.newsblur.domain.UserDetails
import com.newsblur.util.*
import com.newsblur.view.FlowLayout
import java.lang.ref.WeakReference
import java.util.*

class SetupCommentSectionTask(private val fragment: ReadingItemFragment, view: View, inflater: LayoutInflater, story: Story?, iconLoader: ImageLoader) {

    private var topCommentViews: ArrayList<View>? = null
    private var topShareViews: ArrayList<View>? = null
    private var publicCommentViews: ArrayList<View>? = null
    private var friendCommentViews: ArrayList<View>? = null
    private var friendShareViews: ArrayList<View>? = null
    private val story: Story?
    private val inflater: LayoutInflater
    private val viewHolder: WeakReference<View>
    private val context: Context?
    private val user: UserDetails
    private val manager: FragmentManager
    private val iconLoader: ImageLoader
    private var comments: MutableList<Comment>? = null

    /**
     * Do all the DB access and image view creation in the async portion of the task, saving the views in local members.
     */
    fun execute() {
        fragment.lifecycleScope.executeAsyncTask(
                doInBackground = {
                    doInBackground()
                },
                onPostExecute = {
                    onPostExecute()
                }
        )
    }

    private fun doInBackground() {
        if (context == null || story == null) return
        comments = fragment.dbHelper.getComments(story.id)
        topCommentViews = ArrayList()
        topShareViews = ArrayList()
        publicCommentViews = ArrayList()
        friendCommentViews = ArrayList()
        friendShareViews = ArrayList()

        // users by whom we saw non-pseudo comments
        val commentingUserIds: MutableSet<String> = HashSet()
        // users by whom we saw shares
        val sharingUserIds: MutableSet<String> = HashSet()
        for (comment in comments!!) {
            // skip public comments if they are disabled
            if (!comment.byFriend && !PrefsUtils.showPublicComments(context)) {
                continue
            }
            val commentUser = fragment.dbHelper.getUserProfile(comment.userId)
            // rarely, we get a comment but never got the user's profile, so we can't display it
            if (commentUser == null) {
                Log.w(this.javaClass.name, "cannot display comment from missing user ID: " + comment.userId)
                continue
            }
            val commentView = inflater.inflate(R.layout.include_comment, null)
            val commentText = commentView.findViewById<View>(R.id.comment_text) as TextView
            commentText.text = UIUtils.fromHtml(comment.commentText)
            val commentImage = commentView.findViewById<View>(R.id.comment_user_image) as ShapeableImageView
            val commentSharedDate = commentView.findViewById<View>(R.id.comment_shareddate) as TextView
            // TODO: this uses hard-coded "ago" values, which will be wrong when reading prefetched stories
            if (comment.sharedDate != null) {
                commentSharedDate.text = comment.sharedDate + " ago"
            }
            val favouriteContainer = commentView.findViewById<View>(R.id.comment_favourite_avatars) as FlowLayout
            val favouriteIcon = commentView.findViewById<View>(R.id.comment_favourite_icon) as ImageView
            val replyIcon = commentView.findViewById<View>(R.id.comment_reply_icon) as ImageView
            if (comment.likingUsers != null) {
                if (mutableListOf<String>(*comment.likingUsers).contains(user.id)) {
                    favouriteIcon.setImageResource(R.drawable.ic_star_active)
                }
                for (id in comment.likingUsers) {
                    val favouriteImage = ShapeableImageView(context)
                    val user = fragment.dbHelper.getUserProfile(id)
                    if (user != null) {
                        fragment.iconLoader.displayImage(user.photoUrl, favouriteImage)
                        favouriteContainer.addView(favouriteImage)
                    }
                }

                // users cannot fave their own comments.  attempting to do so will actually queue a fatally invalid API call
                if (TextUtils.equals(comment.userId, user.id)) {
                    favouriteIcon.visibility = View.GONE
                } else {
                    favouriteIcon.setOnClickListener {
                        if (!mutableListOf<String>(*comment.likingUsers).contains(user.id)) {
                            fragment.feedUtils.likeComment(story, comment.userId, context)
                        } else {
                            fragment.feedUtils.unlikeComment(story, comment.userId, context)
                        }
                    }
                }
            }
            if (comment.isPlaceholder) {
                replyIcon.visibility = View.INVISIBLE
            } else {
                replyIcon.setOnClickListener {
                    val user = fragment.dbHelper.getUserProfile(comment.userId)
                    if (user != null) {
                        val newFragment: DialogFragment = ReplyDialogFragment.newInstance(story, comment.userId, user.username)
                        newFragment.show(manager, "dialog")
                    }
                }
            }
            val replies = fragment.dbHelper.getCommentReplies(comment.id)
            for (reply in replies) {
                val replyView = inflater.inflate(R.layout.include_reply, null)
                val replyText = replyView.findViewById<View>(R.id.reply_text) as TextView
                replyText.text = UIUtils.fromHtml(reply.text)
                val replyImage = replyView.findViewById<View>(R.id.reply_user_image) as ShapeableImageView
                val replyUser = fragment.dbHelper.getUserProfile(reply.userId)
                if (replyUser != null) {
                    fragment.iconLoader.displayImage(replyUser.photoUrl, replyImage)
                    replyImage.setOnClickListener {
                        val i = Intent(context, Profile::class.java)
                        i.putExtra(Profile.USER_ID, replyUser.userId)
                        context.startActivity(i)
                    }
                    val replyUsername = replyView.findViewById<View>(R.id.reply_username) as TextView
                    replyUsername.text = replyUser.username
                } else {
                    val replyUsername = replyView.findViewById<View>(R.id.reply_username) as TextView
                    replyUsername.setText(R.string.unknown_user)
                }
                if (reply.shortDate != null) {
                    val replySharedDate = replyView.findViewById<View>(R.id.reply_shareddate) as TextView
                    replySharedDate.text = reply.shortDate + " ago"
                }
                val editIcon = replyView.findViewById<View>(R.id.reply_edit_icon) as ImageView
                if (TextUtils.equals(reply.userId, user.id)) {
                    editIcon.setOnClickListener {
                        val newFragment: DialogFragment = EditReplyDialogFragment.newInstance(story, comment.userId, reply.id, reply.text)
                        newFragment.show(manager, "dialog")
                    }
                } else {
                    editIcon.visibility = View.INVISIBLE
                }
                (commentView.findViewById<View>(R.id.comment_replies_container) as LinearLayout).addView(replyView)
            }
            val commentUsername = commentView.findViewById<View>(R.id.comment_username) as TextView
            commentUsername.text = commentUser.username
            val userPhoto = commentUser.photoUrl
            val commentLocation = commentView.findViewById<View>(R.id.comment_location) as TextView
            if (!TextUtils.isEmpty(commentUser.location)) {
                commentLocation.text = commentUser.location
            } else {
                commentLocation.visibility = View.GONE
            }
            if (!TextUtils.isEmpty(comment.sourceUserId)) {
                commentImage.visibility = View.INVISIBLE
                val usershareImage = commentView.findViewById<View>(R.id.comment_user_reshare_image) as ShapeableImageView
                val sourceUserImage = commentView.findViewById<View>(R.id.comment_sharesource_image) as ShapeableImageView
                sourceUserImage.visibility = View.VISIBLE
                usershareImage.visibility = View.VISIBLE
                commentImage.visibility = View.INVISIBLE
                val sourceUser = fragment.dbHelper.getUserProfile(comment.sourceUserId)
                if (sourceUser != null) {
                    fragment.iconLoader.displayImage(sourceUser.photoUrl, sourceUserImage)
                    fragment.iconLoader.displayImage(userPhoto, usershareImage)
                }
            } else {
                fragment.iconLoader.displayImage(userPhoto, commentImage)
            }
            commentImage.setOnClickListener {
                val i = Intent(context, Profile::class.java)
                i.putExtra(Profile.USER_ID, comment.userId)
                context.startActivity(i)
            }
            if (comment.isPseudo) {
                friendShareViews!!.add(commentView)
                sharingUserIds.add(comment.userId)
            } else if (comment.byFriend) {
                friendCommentViews!!.add(commentView)
            } else {
                publicCommentViews!!.add(commentView)
            }

            // for actual comments, also populate the upper icon bar
            if (!comment.isPseudo) {
                val image = ViewUtils.createSharebarImage(context, commentUser.photoUrl, commentUser.userId, iconLoader)
                topCommentViews!!.add(image)
                commentingUserIds.add(comment.userId)
            }
        }

        // the story object supplements the pseudo-comment share list
        for (userId in story.sharedUserIds) {
            // for the purpose of this top-line share list, exclude non-pseudo comments
            if (!commentingUserIds.contains(userId)) {
                sharingUserIds.add(userId)
            }
        }

        // now that we have all shares from the comments table and story object, populate the shares row
        for (userId in sharingUserIds) {
            val user = fragment.dbHelper.getUserProfile(userId)
            if (user == null) {
                Log.w(this.javaClass.name, "cannot display share from missing user ID: $userId")
                continue
            }
            val image = ViewUtils.createSharebarImage(context, user.photoUrl, user.userId, iconLoader)
            topShareViews!!.add(image)
        }
    }

    /**
     * Push all the pre-created views into the actual UI.
     */
    private fun onPostExecute() {
        if (context == null) return
        val view = viewHolder.get() ?: return
        // fragment was dismissed before we rendered
        val headerCommentTotal = view.findViewById<View>(R.id.comment_by) as TextView
        val headerShareTotal = view.findViewById<View>(R.id.shared_by) as TextView
        val sharedGrid = view.findViewById<View>(R.id.reading_social_shareimages) as FlowLayout
        val commentGrid = view.findViewById<View>(R.id.reading_social_commentimages) as FlowLayout
        val friendCommentTotal = view.findViewById<View>(R.id.reading_friend_comment_total) as TextView
        val friendShareTotal = view.findViewById<View>(R.id.reading_friend_emptyshare_total) as TextView
        val publicCommentTotal = view.findViewById<View>(R.id.reading_public_comment_total) as TextView
        val publicCommentCount = publicCommentViews!!.size
        val friendCommentCount = friendCommentViews!!.size
        val friendShareCount = friendShareViews!!.size
        val allCommentCount = topCommentViews!!.size
        val allShareCount = topShareViews!!.size
        if (allCommentCount > 0 || allShareCount > 0) {
            view.findViewById<View>(R.id.reading_share_bar).visibility = View.VISIBLE
            view.findViewById<View>(R.id.share_bar_underline).visibility = View.VISIBLE
        } else {
            view.findViewById<View>(R.id.reading_share_bar).visibility = View.GONE
            view.findViewById<View>(R.id.share_bar_underline).visibility = View.GONE
        }
        sharedGrid.removeAllViews()
        for (image in topShareViews!!) {
            sharedGrid.addView(image)
        }
        commentGrid.removeAllViews()
        for (image in topCommentViews!!) {
            commentGrid.addView(image)
        }
        if (allCommentCount > 0) {
            var countText = context.getString(R.string.friends_comments_count)
            if (allCommentCount == 1) {
                countText = countText.substring(0, countText.length - 1)
            }
            headerCommentTotal.text = String.format(countText, allCommentCount)
            headerCommentTotal.visibility = View.VISIBLE
        } else {
            headerCommentTotal.visibility = View.GONE
        }
        if (allShareCount > 0) {
            var countText = context.getString(R.string.friends_shares_count)
            if (allShareCount == 1) {
                countText = countText.substring(0, countText.length - 1)
            }
            headerShareTotal.text = String.format(countText, allShareCount)
            headerShareTotal.visibility = View.VISIBLE
        } else {
            headerShareTotal.visibility = View.GONE
        }
        if (publicCommentCount > 0) {
            var commentCount = context.getString(R.string.public_comment_count)
            if (publicCommentCount == 1) {
                commentCount = commentCount.substring(0, commentCount.length - 1)
            }
            publicCommentTotal.text = String.format(commentCount, publicCommentCount)
            view.findViewById<View>(R.id.reading_public_comment_header).visibility = View.VISIBLE
        } else {
            view.findViewById<View>(R.id.reading_public_comment_header).visibility = View.GONE
        }
        if (friendCommentCount > 0) {
            var commentCount = context.getString(R.string.friends_comments_count)
            if (friendCommentCount == 1) {
                commentCount = commentCount.substring(0, commentCount.length - 1)
            }
            friendCommentTotal.text = String.format(commentCount, friendCommentCount)
            view.findViewById<View>(R.id.reading_friend_comment_header).visibility = View.VISIBLE
        } else {
            view.findViewById<View>(R.id.reading_friend_comment_header).visibility = View.GONE
        }
        if (friendShareCount > 0) {
            var commentCount = context.getString(R.string.friends_shares_count)
            if (friendShareCount == 1) {
                commentCount = commentCount.substring(0, commentCount.length - 1)
            }
            friendShareTotal.text = String.format(commentCount, friendShareCount)
            view.findViewById<View>(R.id.reading_friend_emptyshare_header).visibility = View.VISIBLE
        } else {
            view.findViewById<View>(R.id.reading_friend_emptyshare_header).visibility = View.GONE
        }
        val publicCommentListContainer = view.findViewById<View>(R.id.reading_public_comment_container) as LinearLayout
        publicCommentListContainer.removeAllViews()
        for (i in publicCommentViews!!.indices) {
            if (i == publicCommentViews!!.size - 1) {
                publicCommentViews!![i].findViewById<View>(R.id.comment_divider).visibility = View.GONE
            }
            publicCommentListContainer.addView(publicCommentViews!![i])
        }
        val friendCommentListContainer = view.findViewById<View>(R.id.reading_friend_comment_container) as LinearLayout
        friendCommentListContainer.removeAllViews()
        for (i in friendCommentViews!!.indices) {
            if (i == friendCommentViews!!.size - 1) {
                friendCommentViews!![i].findViewById<View>(R.id.comment_divider).visibility = View.GONE
            }
            friendCommentListContainer.addView(friendCommentViews!![i])
        }
        val friendShareListContainer = view.findViewById<View>(R.id.reading_friend_emptyshare_container) as LinearLayout
        friendShareListContainer.removeAllViews()
        for (i in friendShareViews!!.indices) {
            if (i == friendShareViews!!.size - 1) {
                friendShareViews!![i].findViewById<View>(R.id.comment_divider).visibility = View.GONE
            }
            friendShareListContainer.addView(friendShareViews!![i])
        }
        fragment.onSocialLoadFinished()
    }

    init {
        context = fragment.requireContext()
        manager = fragment.parentFragmentManager
        this.inflater = inflater
        this.story = story
        viewHolder = WeakReference(view)
        user = PrefsUtils.getUserDetails(context)
        this.iconLoader = iconLoader
    }
}