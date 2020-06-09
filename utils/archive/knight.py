# Screen scrapes the Knight News Challenge entries (all 64 pages of them)
# and counts the number of votes/hearts for each entry. Then displays them
# in rank order.
# 
# This script runs in about 20 seconds.

import requests
from BeautifulSoup import BeautifulSoup

# Winners found on http://newschallenge.tumblr.com/post/20962258701/knight-news-challenge-on-networks-moving-to-the-next:
# 
#     $('.posts .MsoNormal > span').find('a[href^="http://newschallenge.tumblr.com/post"]').map(function() { 
#         return $(this).attr('href');
#     });

winners = [
    "http://newschallenge.tumblr.com/post/20962258701/knight-news-challenge-on-networks-moving-to-the-next#disqus_thread",
    "http://newschallenge.tumblr.com/post/19436493313/amauta-a-collaborative-media-network",
    "http://newschallenge.tumblr.com/post/19493987224/cont3nt-com-lets-you-sell-media-in-real-time-via",
    "http://newschallenge.tumblr.com/post/19494011127/expand-the-unconsumption-project",
    "http://newschallenge.tumblr.com/post/19493557384/mediareputations-com-verifies-your-credentials-and",
    "http://newschallenge.tumblr.com/post/19438230966/prescouter-storify-meets-wikipedia",
    "http://newschallenge.tumblr.com/post/20968613548/themes-surprises-and-outliers-from-1000",
    "http://newschallenge.tumblr.com/post/19436493313/amauta-a-collaborative-media-network",
    "http://newschallenge.tumblr.com/post/19436676620/filling-foreign-news-gaps-with-scholars-asia-beat",
    "http://newschallenge.tumblr.com/post/19478851354/bridging-the-big-data-digital-divide-information",
    "http://newschallenge.tumblr.com/post/19492881188/1-what-do-you-propose-to-do-20-words-scale",
    "http://newschallenge.tumblr.com/post/19121005017/citjo-connecting-twitter-users-with-media-buyers",
    "http://newschallenge.tumblr.com/post/19479493999/connecting-the-global-hacks-hackers-network",
    "http://newschallenge.tumblr.com/post/19436607188/connecting-the-world-with-rural-india-via-facebook-and",
    "http://newschallenge.tumblr.com/post/19493987224/cont3nt-com-lets-you-sell-media-in-real-time-via",
    "http://newschallenge.tumblr.com/post/19438970667/the-cowbird-community-reporting-project",
    "http://newschallenge.tumblr.com/post/19450699629/new-contribution-tools-for-openstreetmap",
    "http://newschallenge.tumblr.com/post/19479653130/differentfeather",
    "http://newschallenge.tumblr.com/post/19478834324/diy-drone-fleets-for-airborne-web-journalism",
    "http://newschallenge.tumblr.com/post/19483270689/docs-to-wordpress-to-indesign",
    "http://newschallenge.tumblr.com/post/19477903682/electoral-college-of-me",
    "http://newschallenge.tumblr.com/post/19404846313/envirofact",
    "http://newschallenge.tumblr.com/post/19490695157/funf-org-open-mobile-sensing",
    "http://newschallenge.tumblr.com/post/19490695157/funf-org-open-mobile-sensing",
    "http://newschallenge.tumblr.com/post/19419901491/global-censorship-monitoring-system",
    "http://newschallenge.tumblr.com/post/19065611908/a-google-news-for-the-social-web",
    "http://newschallenge.tumblr.com/post/19438785842/hawaii-eco-net",
    "http://newschallenge.tumblr.com/post/19180046026/hypothes-is-an-annotation-layer-for-the-web",
    "http://newschallenge.tumblr.com/post/19479029243/iava-new-gi-bill-veterans-alumni-network-vets",
    "http://newschallenge.tumblr.com/post/19436574450/m-health-news-network",
    "http://newschallenge.tumblr.com/post/19493557384/mediareputations-com-verifies-your-credentials-and",
    "http://newschallenge.tumblr.com/post/19480304461/mesh-potato-2-0",
    "http://newschallenge.tumblr.com/post/19479664924/mobile-publishing-for-everyone",
    "http://newschallenge.tumblr.com/post/19494194541/noula-crowdsourcing-needs-mapping-and-developping",
    "http://newschallenge.tumblr.com/post/19484970513/peepol-tv-live-tv-powered-by-and-for-the-people",
    "http://newschallenge.tumblr.com/post/19438230966/prescouter-storify-meets-wikipedia",
    "http://newschallenge.tumblr.com/post/19479504346/prozr-twitter-stories-in-a-snap",
    "http://newschallenge.tumblr.com/post/19345456890/rbutr-follow-online-discourse-between-websites",
    "http://newschallenge.tumblr.com/post/18794349346/recovers-org-community-powered-disaster-recovery",
    "http://newschallenge.tumblr.com/post/19436424823/secure-anonymous-journalism-toolkit",
    "http://newschallenge.tumblr.com/post/19021661497/sensor-networks-for-news",
    "http://newschallenge.tumblr.com/post/19450685278/tethr-evolving-networks",
    "http://newschallenge.tumblr.com/post/19293910540/the-pressforward-dashboard",
    "http://newschallenge.tumblr.com/post/18576274733/thinkup",
    "http://newschallenge.tumblr.com/post/19345435254/1-what-do-you-propose-to-do-20-words-build-a",
    "http://newschallenge.tumblr.com/post/19490689958/truth-goggles",
    "http://newschallenge.tumblr.com/post/19403515934/truth-teller",
    "http://newschallenge.tumblr.com/post/19494011127/expand-the-unconsumption-project",
    "http://newschallenge.tumblr.com/post/19290074949/unicef-gis-youth-led-digital-mapping",
    "http://newschallenge.tumblr.com/post/19397319461/watchup-the-first-news-watcher",
    "http://newschallenge.tumblr.com/post/19493588407/water-canary",
    "http://newschallenge.tumblr.com/post/19480319147/a-bridge-between-wordpress-and-git",
    "http://newschallenge.tumblr.com/post/19414762330/in-the-life-media-transforming-lgbt-journalism",
    "http://newschallenge.tumblr.com/post/19493920734/get-to-the-source",
    "http://newschallenge.tumblr.com/post/19480128205/farm-to-table-school-lunch",
    "http://newschallenge.tumblr.com/post/19477700441/partisans-org",
    "http://newschallenge.tumblr.com/post/19345505702/protecting-journalists-and-engaging-communities"]

def find_entries():
    page = 1
    total_entry_count = 0
    entries = []

    while True:
        print " ---> Found %s entries so far. Now on page: %s" % (len(entries), page)
    
        knight_url = "http://newschallenge.tumblr.com/page/%s" % (page)
        html = requests.get(knight_url).content
        soup = BeautifulSoup(html)
        postboxes = soup.findAll("div", "postbox")
    
        # Done if only sticky entry is left.
        if len(postboxes) <= 1:
            break

        page += 1
        
        # 15 entries per page, plus a sticky throwaway entry
        for entry in postboxes:
            if 'stickyPost' in entry.get('class'): continue
        
            total_entry_count += 1
            likes = entry.find("", "home-likes")
            if likes and likes.text:
                likes = int(likes.text)
            else:
                likes = 0
            
            comments = entry.find("", "home-comments")
            if comments and comments.text:
                comments = int(comments.text)
            else:
                comments = 0
        
            title = entry.find("h2")
            if title:
                title = title.text
            
            url = entry.find('a', "home-view")
            if url:
                url = url.get('href')
            
            # Only record active entries
            if comments or likes:
                entries.append({
                    'likes': likes,
                    'comments': comments,
                    'title': title,
                    'url': url,
                })
        # time.sleep(random.randint(0, 2))
    
    entries.sort(key=lambda e: e['comments'] + e['likes'])
    entries.reverse()
    active_entry_count = len(entries)
    
    found_entries = []
    winner_count = 0
    for i, entry in enumerate(entries):
        is_winner = entry['url'] in winners
        if is_winner: winner_count += 1
        print " * %s#%s: %s likes - [%s](%s)%s" % (
            "**" if is_winner else "",
            i + 1,
            entry['likes'], entry['title'], 
            entry['url'],
            "**" if is_winner else "")
        found_entries.append(entry)
        
    print " ***> Found %s active entries among %s total applications with %s/%s winners." % (
        active_entry_count, total_entry_count, winner_count, len(winners))
    return found_entries

if __name__ == '__main__':
    find_entries()