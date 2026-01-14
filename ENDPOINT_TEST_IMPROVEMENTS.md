# Endpoint Test Improvement Checklist

## Goal
Improve all endpoint tests to:
1. Use strict status code assertions (`== 200`) instead of loose ranges (`in [200, 302, 400]`)
2. Add database verification after each POST that modifies data

---

## Phase 1: High-Impact Files

### ✅ `apps/analyzer/tests/test_urls.py` - COMPLETED
- [x] Add `tearDown` method to clean up MongoDB documents
- [x] `test_save_classifier_post` - strict `== 200`, verify `MClassifierTitle` exists with score=1
- [x] `test_save_classifier_title_post` - verify titles "important", "breaking" with score=1
- [x] `test_save_classifier_author_post` - verify `MClassifierAuthor` exists with score=1
- [x] `test_save_classifier_tag_post` - verify `MClassifierTag` exists with score=1
- [x] `test_save_classifier_dislike_post` - verify score=-1
- [x] `test_save_classifier_remove_like_post` - verify classifier deleted (include `social_user_id=0`)
- [x] `test_get_classifiers_after_save` - verify saved classifiers appear in response

### 🔄 `apps/reader/tests/test_urls.py` - IN PROGRESS
- [x] Add `UserSubscriptionFolders` creation in setUp
- [x] `test_mark_all_as_read_post` - strict `== 200`, verify response JSON structure
- [x] `test_add_folder_post` - verify folder in `UserSubscriptionFolders.folders`
- [x] `test_add_nested_folder_post` - verify nested folder structure
- [x] `test_rename_folder_post` - verify folder renamed in database
- [x] `test_save_feed_order_post` - verify folder order saved
- [x] `test_save_dashboard_rivers_post` - verify dashboard rivers in profile preferences
- [x] `test_retrain_all_sites_post` - verify `is_trained` reset to False
- [x] `test_delete_folder_post` - verify folder removed from database
- [ ] Run tests and fix any remaining failures

### ⬜ `apps/profile/tests/test_urls.py`
- [ ] `test_set_preference_post` - strict `== 200`, verify preference in Profile.preferences JSON
- [ ] `test_set_account_settings_post` - verify user settings updated
- [ ] `test_set_view_setting_post` - verify setting in view_settings JSON
- [ ] `test_set_collapsed_folders_post` - verify collapsed_folders updated
- [ ] `test_activate_premium_trial_post` - verify `is_premium_trial == True` and `is_premium == True`
- [ ] `test_forgot_password_post` - keep as-is (sends email, no DB verification needed)
- [ ] `test_delete_starred_stories_post` - verify starred story count
- [ ] `test_delete_shared_stories_post` - verify shared story count

### ⬜ `apps/social/tests/test_urls.py`
- [ ] `test_save_user_profile_post` - strict `== 200`, verify `MSocialProfile.bio`
- [ ] `test_save_blurblog_settings_post` - verify `MSocialProfile.blurblog_title`
- [ ] `test_social_follow_post` - verify user in `following_user_ids`
- [ ] `test_social_unfollow_post` - verify user not in `following_user_ids`
- [ ] `test_social_mute_user_post` - verify user in `muting_user_ids`
- [ ] `test_social_unmute_user_post` - verify user not in `muting_user_ids`
- [ ] Add tearDown for MongoDB cleanup

---

## Phase 2: Medium-Impact Files

### ⬜ `apps/api/tests/test_urls.py`
- [ ] `test_api_login_post` - strict `== 200`, verify response JSON contains user info
- [ ] `test_api_signup_post` - verify `User.objects.filter(username="newuser")` exists
- [ ] `test_api_add_site_authed_post` - verify `UserSubscription` created

### ⬜ `apps/notifications/tests/test_urls.py`
- [ ] `test_set_notifications_for_feed_post` - strict `== 200`, verify `MUserFeedNotification`
- [ ] `test_set_apns_token_post` - verify token in `MUserNotificationTokens.ios_tokens`
- [ ] `test_set_android_token_post` - verify token storage
- [ ] Add tearDown for MongoDB cleanup

### ⬜ `apps/rss_feeds/tests/test_urls.py`
- [ ] `test_exception_retry_post` - strict `== 200`, verify feed exception handling
- [ ] `test_exception_change_feed_address_post` - verify `feed.feed_address` changed
- [ ] `test_exception_change_feed_link_post` - verify `feed.feed_link` changed
- [ ] `test_original_text_post` - keep `in [200, 404]` (story may not exist)
- [ ] `test_story_changes_post` - keep `in [200, 404]` (story may not exist)

### ⬜ `apps/recommendations/tests/test_urls.py`
- [ ] `test_save_recommended_feed_post` - strict `== 200`, verify `RecommendedFeed`
- [ ] `test_approve_recommended_feed_post` - keep `in [200, 403]` (admin-only)
- [ ] `test_decline_recommended_feed_post` - keep `in [200, 403]` (admin-only)

---

## Phase 3: Lower-Impact Files

### ⬜ `apps/feed_import/tests/test_urls.py`
- [ ] `test_opml_upload_post` - strict `== 200`, verify no error in response

### ⬜ `apps/categories/tests/test_urls.py`
- [ ] `test_categories_subscribe_post` - strict `== 200`, verify subscriptions created

### ⬜ `apps/oauth/tests/test_urls.py`
- [ ] `test_twitter_disconnect_post` - strict `== 200`, verify OAuth token removed
- [ ] `test_facebook_disconnect_post` - strict `== 200`, verify OAuth token removed
- [ ] Twitter/Facebook follow/unfollow - keep as-is (external API)

### ⬜ `apps/ask_ai/tests/test_urls.py`
- [ ] Keep as-is (external API dependencies, error path tests)

---

## Phase 4: No/Minimal Changes Needed

### ⬜ `apps/mobile/tests/test_urls.py`
- [ ] Only redirects - keep `in [200, 302]`

### ⬜ `apps/monitor/tests/test_urls.py`
- [ ] Read-only, admin-protected - keep as-is

### ⬜ `apps/newsletters/tests/test_urls.py`
- [ ] Special email processing - keep loose assertions

### ⬜ `apps/push/tests/test_urls.py`
- [ ] WebSub callbacks use 202 Accepted - keep as-is

### ⬜ `apps/search/tests/test_urls.py`
- [ ] Story may not exist - keep loose assertions

### ⬜ `apps/statistics/tests/test_urls.py`
- [ ] Read-only - keep as-is

---

## Implementation Pattern

For each POST test:
```python
def test_example_post(self):
    """Test POST to example endpoint."""
    self.client.login(username="testuser", password="testpass")

    # POST request
    response = self.client.post(reverse("example-endpoint"), {"param": "value"})

    # Strict status code
    assert response.status_code == 200

    # Verify response JSON
    data = response.json()
    assert data.get("code") == 0  # or appropriate success indicator

    # Database verification
    obj = Model.objects.filter(user=self.user, param="value").first()
    assert obj is not None
    assert obj.field == expected_value
```

For MongoDB tests, add tearDown:
```python
def tearDown(self):
    MClassifierTitle.objects.filter(user_id=self.user.pk).delete()
    MClassifierAuthor.objects.filter(user_id=self.user.pk).delete()
    # etc.
```

---

## Final Verification
- [ ] Run `docker exec -t newsblur_web python manage.py test apps -v 1` to verify all tests pass
