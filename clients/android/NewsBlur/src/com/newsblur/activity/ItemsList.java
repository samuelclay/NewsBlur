package com.newsblur.activity;

import android.os.Bundle;
import android.app.FragmentManager;
import android.text.TextUtils;
import android.util.Log;
import android.view.KeyEvent;
import android.view.MenuItem;
import android.view.View;
import android.view.View.OnKeyListener;
import android.widget.EditText;
import android.widget.SeekBar;
import android.widget.SeekBar.OnSeekBarChangeListener;
import android.widget.TextView;

import butterknife.ButterKnife;
import butterknife.Bind;

import com.newsblur.R;
import com.newsblur.fragment.DefaultFeedViewDialogFragment;
import com.newsblur.fragment.ItemListFragment;
import com.newsblur.fragment.MarkAllReadDialogFragment;
import com.newsblur.fragment.MarkAllReadDialogFragment.MarkAllReadDialogListener;
import com.newsblur.fragment.ReadFilterDialogFragment;
import com.newsblur.fragment.StoryOrderDialogFragment;
import com.newsblur.fragment.TextSizeDialogFragment;
import com.newsblur.service.NBSyncService;
import com.newsblur.util.AppConstants;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.DefaultFeedViewChangedListener;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.MarkAllReadConfirmation;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.ReadFilterChangedListener;
import com.newsblur.util.StateFilter;
import com.newsblur.util.StoryOrder;
import com.newsblur.util.StoryOrderChangedListener;
import com.newsblur.util.UIUtils;

public abstract class ItemsList extends NbActivity implements StoryOrderChangedListener, ReadFilterChangedListener, DefaultFeedViewChangedListener, MarkAllReadDialogListener, OnSeekBarChangeListener {

    public static final String EXTRA_FEED_SET = "feed_set";

	private static final String STORY_ORDER = "storyOrder";
	private static final String READ_FILTER = "readFilter";
    private static final String DEFAULT_FEED_VIEW = "defaultFeedView";
    private static final String BUNDLE_ACTIVE_SEARCH_QUERY = "activeSearchQuery";

	protected ItemListFragment itemListFragment;
	protected FragmentManager fragmentManager;
    @Bind(R.id.itemlist_sync_status) TextView overlayStatusText;
    @Bind(R.id.itemlist_search_query) EditText searchQueryInput;
	protected StateFilter intelState;

    protected FeedSet fs;
	
	@Override
    protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);

        overridePendingTransition(R.anim.slide_in_from_right, R.anim.slide_out_to_left);

		fs = (FeedSet) getIntent().getSerializableExtra(EXTRA_FEED_SET);

		intelState = PrefsUtils.getStateFilter(this);

        getWindow().setBackgroundDrawableResource(android.R.color.transparent);

		setContentView(R.layout.activity_itemslist);
        ButterKnife.bind(this);
		fragmentManager = getFragmentManager();

        if (PrefsUtils.isAutoOpenFirstUnread(this)) {
            if (FeedUtils.dbHelper.getUnreadCount(fs, intelState) > 0) {
                UIUtils.startReadingActivity(fs, Reading.FIND_FIRST_UNREAD, this);
            }
        }

        if (bundle != null) {
            String activeSearchQuery = bundle.getString(BUNDLE_ACTIVE_SEARCH_QUERY);
            if (activeSearchQuery != null) {
                searchQueryInput.setText(activeSearchQuery);
                searchQueryInput.setVisibility(View.VISIBLE);
                fs.setSearchQuery(activeSearchQuery);
            }
        }
        searchQueryInput.setOnKeyListener(new OnKeyListener() {
            public boolean onKey(View v, int keyCode, KeyEvent event) {
                if ((keyCode == KeyEvent.KEYCODE_BACK) && (event.getAction() == KeyEvent.ACTION_DOWN)) {
                    searchQueryInput.setVisibility(View.GONE);
                    searchQueryInput.setText("");
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
        if (searchQueryInput != null) {
            String q = searchQueryInput.getText().toString().trim();
            if (q.length() > 0) {
                outState.putString(BUNDLE_ACTIVE_SEARCH_QUERY, q);
            }
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
        itemListFragment.hasUpdated();
    }

    @Override
    protected void onPause() {
        super.onPause();
        NBSyncService.addRecountCandidates(fs);
    }

	public void markItemListAsRead() {
        MarkAllReadConfirmation confirmation = PrefsUtils.getMarkAllReadConfirmation(this);
        if (confirmation.feedSetRequiresConfirmation(fs)) {
            MarkAllReadDialogFragment dialog = MarkAllReadDialogFragment.newInstance(fs);
            dialog.show(fragmentManager, "dialog");
        } else {
            onMarkAllRead(fs);
        }
    }

    @Override
    public void onMarkAllRead(FeedSet feedSet) {
        if (itemListFragment != null) {
            // since v6.0 of Android, the ListView in the fragment likes to crash if the underlying
            // dataset changes rapidly as happens when marking-all-read and when the fragment is
            // stopping. do a manual hard-stop of the loaders in the fragment before we finish
            itemListFragment.stopLoader();
        }
        FeedUtils.markFeedsRead(fs, null, null, this);
        finish();
    }
	
	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		if (item.getItemId() == android.R.id.home) {
			finish();
			return true;
		} else if (item.getItemId() == R.id.menu_mark_all_as_read) {
			markItemListAsRead();
			return true;
		} else if (item.getItemId() == R.id.menu_story_order) {
            StoryOrder currentValue = getStoryOrder();
            StoryOrderDialogFragment storyOrder = StoryOrderDialogFragment.newInstance(currentValue);
            storyOrder.show(getFragmentManager(), STORY_ORDER);
            return true;
        } else if (item.getItemId() == R.id.menu_read_filter) {
            ReadFilter currentValue = getReadFilter();
            ReadFilterDialogFragment readFilter = ReadFilterDialogFragment.newInstance(currentValue);
            readFilter.show(getFragmentManager(), READ_FILTER);
            return true;
        } else if (item.getItemId() == R.id.menu_default_view) {
            DefaultFeedView currentValue = PrefsUtils.getDefaultFeedView(this, fs);
            DefaultFeedViewDialogFragment readFilter = DefaultFeedViewDialogFragment.newInstance(currentValue);
            readFilter.show(getFragmentManager(), DEFAULT_FEED_VIEW);
            return true;
		} else if (item.getItemId() == R.id.menu_textsize) {
			TextSizeDialogFragment textSize = TextSizeDialogFragment.newInstance(PrefsUtils.getListTextSize(this), TextSizeDialogFragment.TextSizeType.ListText);
			textSize.show(getFragmentManager(), TextSizeDialogFragment.class.getName());
			return true;
        } else if (item.getItemId() == R.id.menu_search_stories) {
            if (searchQueryInput.getVisibility() != View.VISIBLE) {
                searchQueryInput.setVisibility(View.VISIBLE);
                searchQueryInput.requestFocus();
            } else {
                searchQueryInput.setVisibility(View.GONE);
            }
        }
	
		return false;
	}
	
	public StoryOrder getStoryOrder() {
        return PrefsUtils.getStoryOrder(this, fs);
    }
    
	protected void updateStoryOrderPreference(StoryOrder newOrder) {
        PrefsUtils.updateStoryOrder(this, fs, newOrder);
    }
	
	protected abstract ReadFilter getReadFilter();

    @Override
	public void handleUpdate(int updateType) {
        if ((updateType & UPDATE_REBUILD) != 0) {
            finish();
        }
        if ((updateType & UPDATE_STATUS) != 0) {
            updateStatusIndicators();
        }
		if ((updateType & UPDATE_STORY) != 0) {
            if (itemListFragment != null) {
			    itemListFragment.hasUpdated();
            }
        }
    }

    private void updateStatusIndicators() {
        boolean isLoading = NBSyncService.isFeedSetSyncing(this.fs, this);
        if (itemListFragment != null) {
            itemListFragment.setLoading(isLoading);
        }

        if (overlayStatusText != null) {
            String syncStatus = NBSyncService.getSyncStatusMessage(this, true);
            if (syncStatus != null)  {
                if (AppConstants.VERBOSE_LOG) {
                    syncStatus = syncStatus + UIUtils.getMemoryUsageDebug(this);
                }
                overlayStatusText.setText(syncStatus);
                overlayStatusText.setVisibility(View.VISIBLE);
            } else {
                overlayStatusText.setVisibility(View.GONE);
            }
        }
    }

    private void checkSearchQuery() {
        String oldQuery = fs.getSearchQuery();
        String q = searchQueryInput.getText().toString().trim();
        if (q.length() < 1) {
            q = null;
        }
        fs.setSearchQuery(q);
        if (!TextUtils.equals(q, oldQuery)) {
            NBSyncService.resetReadingSession();
            NBSyncService.resetFetchState(fs);
            itemListFragment.resetEmptyState();
            itemListFragment.hasUpdated();
            itemListFragment.scrollToTop();
        }
    }

	@Override
    public void storyOrderChanged(StoryOrder newValue) {
        updateStoryOrderPreference(newValue);
        itemListFragment.resetEmptyState();
        itemListFragment.hasUpdated();
        itemListFragment.scrollToTop();
        NBSyncService.resetFetchState(fs);
        triggerSync();
    }

    @Override
    public void readFilterChanged(ReadFilter newValue) {
        updateReadFilterPreference(newValue);
        itemListFragment.resetEmptyState();
        itemListFragment.hasUpdated();
        itemListFragment.scrollToTop();
        NBSyncService.resetFetchState(fs);
        triggerSync();
    }

    // NB: this callback is for the text size slider
	@Override
	public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
        float size = AppConstants.LIST_FONT_SIZE[progress];
	    PrefsUtils.setListTextSize(this, size);
        if (itemListFragment != null) itemListFragment.setTextSize(size);
	}

    // unused OnSeekBarChangeListener method
	@Override
	public void onStartTrackingTouch(SeekBar seekBar) {
	}

    // unused OnSeekBarChangeListener method
	@Override
	public void onStopTrackingTouch(SeekBar seekBar) {
	}

    protected abstract void updateReadFilterPreference(ReadFilter newValue);

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
}
