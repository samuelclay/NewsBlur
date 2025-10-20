# frozen_string_literal: true

# Plugin to generate paginated RSS feeds with RFC 5005 archive links
# This allows feed readers like NewsBlur to backfill the entire blog archive

module Jekyll
  class PaginatedFeedGenerator < Generator
    safe true
    priority :low  # Run after other generators like jekyll-feed

    POSTS_PER_PAGE = 25

    def generate(site)
      return unless site.config['paginate_feeds']

      # Remove any existing feed.xml pages (e.g., from jekyll-feed)
      site.pages.reject! { |page| page.name == 'feed.xml' || page.name =~ /^feed-page-\d+\.xml$/ }

      all_posts = site.posts.docs.reverse # Newest first
      total_posts = all_posts.length
      total_pages = (total_posts.to_f / POSTS_PER_PAGE).ceil

      # Generate a feed page for each page of posts
      (1..total_pages).each do |page_num|
        offset = (page_num - 1) * POSTS_PER_PAGE
        posts = all_posts[offset, POSTS_PER_PAGE]

        # Create the feed page
        feed_page = PaginatedFeedPage.new(site, site.source, page_num, total_pages, posts)
        site.pages << feed_page
      end
    end
  end

  class PaginatedFeedPage < Page
    def initialize(site, base, page_num, total_pages, posts)
      @site = site
      @base = base
      @dir = ''

      # Page 1 is feed.xml, others are feed-page-N.xml
      @name = page_num == 1 ? 'feed.xml' : "feed-page-#{page_num}.xml"

      self.process(@name)
      self.read_yaml(File.join(base, '_layouts'), 'paginated_feed.xml')

      # Pass data to the template
      self.data['page_num'] = page_num
      self.data['total_pages'] = total_pages
      self.data['posts'] = posts
      self.data['has_previous'] = page_num > 1
      self.data['has_next'] = page_num < total_pages
      self.data['previous_page_url'] = page_num == 2 ? 'feed.xml' : "feed-page-#{page_num - 1}.xml"
      self.data['next_page_url'] = "feed-page-#{page_num + 1}.xml"
    end
  end

  # Hook to ensure our feeds are written after jekyll-feed
  Jekyll::Hooks.register :site, :post_write do |site|
    next unless site.config['paginate_feeds']

    # Remove jekyll-feed's feed.xml if it exists and is empty/wrong
    feed_path = File.join(site.dest, 'feed.xml')
    if File.exist?(feed_path)
      content = File.read(feed_path)
      # If it's jekyll-feed's version (check for empty entries or missing RFC 5005 links)
      if !content.include?('rel="next"') && !content.include?('<entry>')
        File.delete(feed_path)

        # Force regeneration of our feed.xml
        feed_page = site.pages.find { |p| p.name == 'feed.xml' && p.data['page_num'] }
        feed_page.write(site.dest) if feed_page
      end
    end
  end
end
