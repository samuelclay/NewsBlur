package com.newsblur.fragment;

import java.util.ArrayList;
import java.util.HashSet;

import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.os.AsyncTask;
import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.text.TextUtils;
import android.util.Base64;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.CompoundButton;
import android.widget.CompoundButton.OnCheckedChangeListener;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.activity.ImportFeeds;
import com.newsblur.domain.Category;
import com.newsblur.domain.Feed;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.CategoriesResponse;

public class AddSitesListFragment extends Fragment {

	private Button importReaderButton;
	private CategoriesResponse response;
	private APIManager apiManager;
	private View parentView;
	private boolean readerImported = false;
	
	HashSet<String> categoriesToAdd = new HashSet<String>();

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setRetainInstance(true);
		apiManager = new APIManager(getActivity());
	}
	
	public ArrayList<String> getSelectedCategories() {
		ArrayList<String> categoriesArrayList = new ArrayList<String>();
		categoriesArrayList.addAll(categoriesToAdd);
		return categoriesArrayList;
	}

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		parentView = inflater.inflate(R.layout.fragment_addsites, null);

		importReaderButton = (Button) parentView.findViewById(R.id.login_add_reader_button);
		importReaderButton.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View v) {
				Intent i = new Intent(getActivity(), ImportFeeds.class);
				startActivityForResult(i, 0);
			}
		});

		if (response == null) {
			new AsyncTask<Void, Void, Void>() {
				@Override
				protected Void doInBackground(Void... params) {
					response = apiManager.getCategories();
					return null;
				}

				protected void onPostExecute(Void result) {
					setupUI();
				};

			}.execute();
		} else {
			setupUI();
		}

		if (readerImported) {
			importReaderButton.setEnabled(false);
			importReaderButton.setText("Feeds imported!");
		}
		
		return parentView;
	}

	private void setupUI() {
		LayoutInflater inflater = getActivity().getLayoutInflater();
		LinearLayout categoryContainer = (LinearLayout) parentView.findViewById(R.id.login_categories_container);

		parentView.findViewById(R.id.login_categories_progress).setVisibility(View.GONE);

		for (final Category category : response.categories) {
			LinearLayout categoryView = (LinearLayout) inflater.inflate(R.layout.include_category, null);
			TextView categoryTitle = (TextView) categoryView.findViewById(R.id.category_title);

			CheckBox categoryCheckbox = (CheckBox) categoryView.findViewById(R.id.category_checkbox);
			categoryCheckbox.setOnCheckedChangeListener(new OnCheckedChangeListener() {
				@Override
				public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
					if (isChecked) {
						categoriesToAdd.add(category.title);
					} else {
						categoriesToAdd.remove(category.title);
					
					}
				}
			});
			
			categoryCheckbox.setChecked(categoriesToAdd.contains(category.title));
			
			categoryTitle.setText(category.title);
			for (String feedId : category.feedIds) {
				Feed feed = response.feeds.get(feedId);
				View feedView = inflater.inflate(R.layout.merge_category_feed, null);
				TextView feedTitle = (TextView) feedView.findViewById(R.id.login_category_feed_title);
				feedTitle.setText(feed.title);

				View borderOne = feedView.findViewById(R.id.login_category_feed_leftbar);
				View borderTwo = feedView.findViewById(R.id.login_category_feed_rightbar);

				if (!TextUtils.isEmpty(feed.faviconColour) && !TextUtils.equals(feed.faviconColour, "null")) {
					borderOne.setBackgroundColor(Color.parseColor("#".concat(feed.faviconColour)));
					borderTwo.setBackgroundColor(Color.parseColor("#".concat(feed.faviconColour)));
				} else {
					borderOne.setBackgroundColor(Color.LTGRAY);
					borderTwo.setBackgroundColor(Color.LTGRAY);
				}

				Bitmap bitmap = null;
				if (!TextUtils.isEmpty(feed.favicon)) {
					final byte[] data = Base64.decode(feed.favicon, Base64.DEFAULT);
					bitmap = BitmapFactory.decodeByteArray(data, 0, data.length);
				} else {
					bitmap = BitmapFactory.decodeResource(getActivity().getResources(), R.drawable.world);
				}
				((ImageView) feedView.findViewById(R.id.login_category_feed_icon)).setImageBitmap(bitmap);

				categoryView.addView(feedView);
			}

			categoryContainer.addView(categoryView);
		}
	}

	public void setGoogleReaderImported() {
		readerImported = true;
		importReaderButton.setEnabled(false);
		importReaderButton.setText("Feeds imported successfully!");
	}

}
