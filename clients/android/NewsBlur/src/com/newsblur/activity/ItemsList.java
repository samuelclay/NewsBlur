package com.newsblur.activity;

import static com.newsblur.service.NBSyncReceiver.UPDATE_REBUILD;
import static com.newsblur.service.NBSyncReceiver.UPDATE_STATUS;
import static com.newsblur.service.NBSyncReceiver.UPDATE_STORY;

import android.os.Bundle;

import androidx.annotation.Nullable;
import androidx.fragment.app.FragmentManager;
import androidx.fragment.app.FragmentTransaction;
import androidx.lifecycle.ViewModelProvider;

import android.text.TextUtils;
import android.view.KeyEvent;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.View.OnKeyListener;

import com.newsblur.R;
import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.databinding.ActivityItemslistBinding;
import com.newsblur.delegate.ItemListContextMenuDelegate;
import com.newsblur.delegate.ItemListContextMenuDelegateImpl;
import com.newsblur.fragment.ItemSetFragment;
import com.newsblur.service.NBSyncService;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.ReadingActionListener;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.Session;
import com.newsblur.util.SessionDataSource;
import com.newsblur.util.StateFilter;
import com.newsblur.util.UIUtils;
import com.newsblur.viewModel.ItemListViewModel;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public abstract class ItemsList extends NbActivity implements ReadingActionListener {

    @Inject
    BlurDatabaseHelper dbHelper;

    @Inject
    FeedUtils feedUtils;

    public static final String EXTRA_FEED_SET = "feed_set";
    public static final String EXTRA_STORY_HASH = "story_hash";
    public static final String EXTRA_WIDGET_STORY = "widget_story";
    public static final String EXTRA_VISIBLE_SEARCH = "visibleSearch";
    public static final String EXTRA_SESSION_DATA = "session_data";
    private static final String BUNDLE_ACTIVE_SEARCH_QUERY = "activeSearchQuery";

    protected ItemListViewModel viewModel;
    protected FeedSet fs;

    private ItemSetFragment itemSetFragment;
    private ActivityItemslistBinding binding;
    private ItemListContextMenuDelegate contextMenuDelegate;
    @Nullable
    private SessionDataSource sessionDataSource;
	
	@Override
    protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);

        overridePendingTransition(R.anim.slide_in_from_right, R.anim.slide_out_to_left);

        contextMenuDelegate = new ItemListContextMenuDelegateImpl(this, feedUtils);
        viewModel = new ViewModelProvider(this).get(ItemListViewModel.class);
		fs = (FeedSet) getIntent().getSerializableExtra(EXTRA_FEED_SET);
        sessionDataSource = (SessionDataSource) getIntent().getSerializableExtra(EXTRA_SESSION_DATA);

        // this is not strictly necessary, since our first refresh with the fs will swap in
        // the correct session, but that can be delayed by sync backup, so we try here to
        // reduce UI lag, or in case somehow we got redisplayed in a zero-story state
        feedUtils.prepareReadingSession(fs, false);
        if (getIntent().getBooleanExtra(EXTRA_WIDGET_STORY, false)) {
            String hash = (String) getIntent().getSerializableExtra(EXTRA_STORY_HASH);
            UIUtils.startReadingActivity(fs, hash, this);
        } else if (PrefsUtils.isAutoOpenFirstUnread(this)) {
            StateFilter intelState = PrefsUtils.getStateFilter(this);
            if (dbHelper.getUnreadCount(fs, intelState) > 0) {
                UIUtils.startReadingActivity(fs, Reading.FIND_FIRST_UNREAD, this);
            }
        }

        getWindow().setBackgroundDrawableResource(android.R.color.transparent);

        binding = ActivityItemslistBinding.inflate(getLayoutInflater());
		setContentView(binding.getRoot());

		FragmentManager fragmentManager = getSupportFragmentManager();
		itemSetFragment = (ItemSetFragment) fragmentManager.findFragmentByTag(ItemSetFragment.class.getName());
		if (itemSetFragment == null) {
            itemSetFragment = ItemSetFragment.newInstance();
			FragmentTransaction transaction = fragmentManager.beginTransaction();
			transaction.add(R.id.activity_itemlist_container, itemSetFragment, ItemSetFragment.class.getName());
			transaction.commit();
		}

        String activeSearchQuery;
        if (bundle != null) {
            activeSearchQuery = bundle.getString(BUNDLE_ACTIVE_SEARCH_QUERY);
        } else {
            activeSearchQuery = fs.getSearchQuery();
        }
        if (activeSearchQuery != null) {
            binding.itemlistSearchQuery.setText(activeSearchQuery);
            binding.itemlistSearchQuery.setVisibility(View.VISIBLE);
        } else if (getIntent().getBooleanExtra(EXTRA_VISIBLE_SEARCH, false)){
            binding.itemlistSearchQuery.setVisibility(View.VISIBLE);
            binding.itemlistSearchQuery.requestFocus();
        }

        binding.itemlistSearchQuery.setOnKeyListener(new OnKeyListener() {
            public boolean onKey(View v, int keyCode, KeyEvent event) {
                if ((keyCode == KeyEvent.KEYCODE_BACK) && (event.getAction() == KeyEvent.ACTION_DOWN)) {
                    binding.itemlistSearchQuery.setVisibility(View.GONE);
                    binding.itemlistSearchQuery.setText("");
                    checkSearchQuery();
                    return true;
                }
                if ((keyCode == KeyEvent.KEYCODE_ENTER) && (event.getAction() == KeyEvent.ACTION_DOWN)) {
                    checkSearchQuery();
                    return true;
                }   
                return false;
            }
        });
	}

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        String q = binding.itemlistSearchQuery.getText().toString().trim();
        if (q.length() > 0) {
            outState.putString(BUNDLE_ACTIVE_SEARCH_QUERY, q);
        }
    }

    public FeedSet getFeedSet() {
        return this.fs;
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (NBSyncService.isHousekeepingRunning()) finish();
        updateStatusIndicators();
        // Reading activities almost certainly changed the read/unread state of some stories. Ensure
        // we reflect those changes promptly.
        itemSetFragment.hasUpdated();
    }

    @Override
    protected void onPause() {
        super.onPause();
        NBSyncService.addRecountCandidates(fs);
    }

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		return contextMenuDelegate.onCreateMenuOptions(menu, getMenuInflater(), fs);
	}

	@Override
	public boolean onPrepareOptionsMenu(Menu menu) {
        super.onPrepareOptionsMenu(menu);
        boolean showSavedSearch = !TextUtils.isEmpty(binding.itemlistSearchQuery.getText());
        return contextMenuDelegate.onPrepareMenuOptions(menu, fs, showSavedSearch);
    }

    @Override
	public boolean onOptionsItemSelected(MenuItem item) {
        return contextMenuDelegate.onOptionsItemSelected(item, itemSetFragment, fs, binding.itemlistSearchQuery, getSaveSearchFeedId());
	}

    @Override
	public void handleUpdate(int updateType) {
        if ((updateType & UPDATE_REBUILD) != 0) {
            finish();
        }
        if ((updateType & UPDATE_STATUS) != 0) {
            updateStatusIndicators();
        }
		if ((updateType & UPDATE_STORY) != 0) {
            if (itemSetFragment != null) {
			    itemSetFragment.hasUpdated();
            }
        }
    }

    @Override
    public void onReadingActionCompleted() {
        if (sessionDataSource != null) {
            Session session = sessionDataSource.getNextSession();
            if (session != null) {
                // set the next session on the parent activity
                fs = session.getFeedSet();
                feedUtils.prepareReadingSession(fs, false);
                triggerSync();

                // set the next session on the child activity
                viewModel.updateSession(session);

                // update item set fragment
                itemSetFragment.resetEmptyState();
                itemSetFragment.hasUpdated();
                itemSetFragment.scrollToTop();
            } else finish();
        } else finish();
    }

    private void updateStatusIndicators() {
        if (binding.itemlistSyncStatus != null) {
            String syncStatus = NBSyncService.getSyncStatusMessage(this, true);
            if (syncStatus != null)  {
                if (AppConstants.VERBOSE_LOG) {
                    syncStatus = syncStatus + UIUtils.getMemoryUsageDebug(this);
                }
                binding.itemlistSyncStatus.setText(syncStatus);
                binding.itemlistSyncStatus.setVisibility(View.VISIBLE);
            } else {
                binding.itemlistSyncStatus.setVisibility(View.GONE);
            }
        }
    }

    private void checkSearchQuery() {
        String q = binding.itemlistSearchQuery.getText().toString().trim();
        if (q.length() < 1) {
            updateFleuron(false);
            q = null;
        } else if (!PrefsUtils.getIsPremium(this)) {
            updateFleuron(true);
            return;
        }

        String oldQuery = fs.getSearchQuery();
        fs.setSearchQuery(q);
        if (!TextUtils.equals(q, oldQuery)) {
            feedUtils.prepareReadingSession(fs, true);
            triggerSync();
            itemSetFragment.resetEmptyState();
            itemSetFragment.hasUpdated();
            itemSetFragment.scrollToTop();
        }
    }

    private void updateFleuron(boolean requiresPremium) {
	    FragmentTransaction transaction = getSupportFragmentManager()
                .beginTransaction()
                .setCustomAnimations(android.R.animator.fade_in, android.R.animator.fade_out);

	    if (requiresPremium) {
	        transaction.hide(itemSetFragment);
            binding.footerFleuron.textSubscription.setText(R.string.premium_subscribers_search);
            binding.footerFleuron.containerSubscribe.setVisibility(View.VISIBLE);
            binding.footerFleuron.getRoot().setVisibility(View.VISIBLE);
            binding.footerFleuron.containerSubscribe.setOnClickListener(view -> UIUtils.startPremiumActivity(this));
        } else {
	        transaction.show(itemSetFragment);
            binding.footerFleuron.containerSubscribe.setVisibility(View.GONE);
            binding.footerFleuron.getRoot().setVisibility(View.GONE);
            binding.footerFleuron.containerSubscribe.setOnClickListener(null);
        }
	    transaction.commit();
    }

    protected void restartReadingSession() {
        NBSyncService.resetFetchState(fs);
        feedUtils.prepareReadingSession(fs, true);
        triggerSync();
        itemSetFragment.resetEmptyState();
        itemSetFragment.hasUpdated();
        itemSetFragment.scrollToTop();
    }

    @Override
    public void finish() {
        super.finish();
        /*
         * Animate out the list by sliding it to the right and the Main activity in from
         * the left.  Do this when going back to Main as a subtle hint to the swipe gesture,
         * to make the gesture feel more natural, and to override the really ugly transition
         * used in some of the newer platforms.
         */
        overridePendingTransition(R.anim.slide_in_from_left, R.anim.slide_out_to_right);
    }

    abstract String getSaveSearchFeedId();

}
