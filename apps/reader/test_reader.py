from utils import json_functions as json
from django.test.client import Client
from django.test import TestCase
from django.urls import reverse
from django.conf import settings
from mongoengine.connection import connect, disconnect

class Test_Reader(TestCase):
    fixtures = [
        'apps/rss_feeds/fixtures/initial_data.json',
        'apps/rss_feeds/fixtures/rss_feeds.json', 
        'subscriptions.json', #'stories.json', 
        'apps/rss_feeds/fixtures/gawker1.json']
    
    def setUp(self):
        disconnect()
        settings.MONGODB = connect('test_newsblur')
        self.client = Client()

    def tearDown(self):
        settings.MONGODB.drop_database('test_newsblur')
            
    def test_api_feeds(self):
        self.client.login(username='conesus', password='test')
      
        response = self.client.get(reverse('load-feeds'))
        content = json.decode(response.content)
        self.assertEqual(len(content['feeds']), 10)
        self.assertEqual(content['feeds']['1']['feed_title'], 'The NewsBlur Blog')
        self.assertEqual(content['folders'], [{'Tech': [1, 4, 5, {'Deep Tech': [6, 7]}]}, 2, 3, 8, 9, {'Blogs': [8, 9]}, 1])
        
    def test_delete_feed(self):
        self.client.login(username='conesus', password='test')
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEqual(feeds['folders'], [{'Tech': [1, 4, 5, {'Deep Tech': [6, 7]}]}, 2, 3, 8, 9, {'Blogs': [8, 9]}, 1])
        
        # Delete feed
        response = self.client.post(reverse('delete-feed'), {'feed_id': 1, 'in_folder': ''})
        response = json.decode(response.content)
        self.assertEqual(response['code'], 1)
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEqual(feeds['folders'], [2, 3, 8, 9, {'Tech': [1, 4, 5, {'Deep Tech': [6, 7]}]}, {'Blogs': [8, 9]}])
        
        # Delete feed
        response = self.client.post(reverse('delete-feed'), {'feed_id': 9, 'in_folder': 'Blogs'})
        response = json.decode(response.content)
        self.assertEqual(response['code'], 1)
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEqual(feeds['folders'], [2, 3, 8, 9, {'Tech': [1, 4, 5, {'Deep Tech': [6, 7]}]}, {'Blogs': [8]}])
        
        # Delete feed
        response = self.client.post(reverse('delete-feed'), {'feed_id': 5, 'in_folder': 'Tech'})
        response = json.decode(response.content)
        self.assertEqual(response['code'], 1)
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEqual(feeds['folders'], [2, 3, 8, 9, {'Tech': [1, 4, {'Deep Tech': [6, 7]}]}, {'Blogs': [8]}])
        
        # Delete feed
        response = self.client.post(reverse('delete-feed'), {'feed_id': 4, 'in_folder': 'Tech'})
        response = json.decode(response.content)
        self.assertEqual(response['code'], 1)
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEqual(feeds['folders'], [2, 3, 8, 9, {'Tech': [1, {'Deep Tech': [6, 7]}]}, {'Blogs': [8]}])
        
        # Delete feed
        response = self.client.post(reverse('delete-feed'), {'feed_id': 8, 'in_folder': ''})
        response = json.decode(response.content)
        self.assertEqual(response['code'], 1)
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEqual(feeds['folders'], [2, 3, 9, {'Tech': [1, {'Deep Tech': [6, 7]}]}, {'Blogs': [8]}])

    def test_delete_feed__multiple_folders(self):
        self.client.login(username='conesus', password='test')
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEqual(feeds['folders'], [{'Tech': [1, 4, 5, {'Deep Tech': [6, 7]}]}, 2, 3, 8, 9, {'Blogs': [8, 9]}, 1])
        
        # Delete feed
        response = self.client.post(reverse('delete-feed'), {'feed_id': 1})
        response = json.decode(response.content)
        self.assertEqual(response['code'], 1)
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEqual(feeds['folders'], [2, 3, 8, 9, {'Tech': [1, 4, 5, {'Deep Tech': [6, 7]}]}, {'Blogs': [8, 9]}])
    
    def test_move_feeds_by_folder(self):
        self.client.login(username='Dejal', password='test')

        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEqual(feeds['folders'], [5299728, 644144, 1187026, {"Brainiacs & Opinion": [569, 38, 3581, 183139, 1186180, 15]}, {"Science & Technology": [731503, 140145, 1272495, 76, 161, 39, {"Hacker": [5985150, 3323431]}]}, {"Humor": [212379, 3530, 5994357]}, {"Videos": [3240, 5168]}])
        
        # Move feeds by folder
        response = self.client.post(reverse('move-feeds-by-folder-to-folder'), {'feeds_by_folder': '[\n  [\n    "5994357",\n    "Humor"\n  ],\n  [\n    "3530",\n    "Humor"\n  ]\n]', 'to_folder': 'Brainiacs & Opinion'})
        response = json.decode(response.content)
        self.assertEqual(response['code'], 1)
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEqual(feeds['folders'], [5299728, 644144, 1187026, {"Brainiacs & Opinion": [569, 38, 3581, 183139, 1186180, 15, 5994357, 3530]}, {"Science & Technology": [731503, 140145, 1272495, 76, 161, 39, {"Hacker": [5985150, 3323431]}]}, {"Humor": [212379]}, {"Videos": [3240, 5168]}])
        
    def test_load_single_feed(self):
        # from django.conf import settings
        # from django.db import connection
        # settings.DEBUG = True
        # connection.queries = []

        self.client.login(username='conesus', password='test')        
        url = reverse('load-single-feed', kwargs=dict(feed_id=1))
        response = self.client.get(url)
        feed = json.decode(response.content)
        self.assertEqual(len(feed['feed_tags']), 0)
        self.assertEqual(len(feed['classifiers']['tags']), 0)
        # self.assert_(connection.queries)
        
        # settings.DEBUG = False
    
    def test_compact_user_subscription_folders(self):
        usf = UserSubscriptionFolders.objects.get(user=User.objects.all()[0])
        usf.folders = '[2, 3, {"Bloglets": [423, 424, 425]}, {"Blogs": [426, 427, 428, 429, 430, 431, 432, 433, 434, 435, 436, 437, 438, 439, 440, 441, 442, 443, 444, 445, 446, 447, 448, 449, 450, 451, 452, 453, 454, 455, 456, 457, 458, 459, 460, 461, 462, 463, 464, 465, 466, {"People": [471, 472, 473, 474, 475, 476, 477, 478, 479, 480, 481, 482, 483, 484, 485, 486, 487, 488, 489, 490, 491, 492, 493, 494, 495, 496, 497, 498, 499, 500, 501, 502, 503, 504, 505, 506, 507, 508, 509, 510, 511, 512, 513, 514, 515, 516, 517, 518, 519, 520, 521, 522, 523, 524, 525, 526, 527, 528, 867, 946, 947, 948]}, {"Tumblrs": [529, 530, 531, 532, 533, 534, 535, 536, 537, 538, 539, 540, 541, 542, 543, 544, 545, 546, 547, 548, 549]}, {"Photo Blogs": [550, 551, 552, 553, 554, 555, 556]}, {"Travel": [557, 558, 559]}, {"People": [471, 472, 473, 474, 475, 476, 477, 478, 479, 480, 481, 482, 483, 484, 485, 486, 487, 488, 489, 490, 491, 492, 493, 494, 495, 496, 497, 498, 499, 500, 501, 502, 503, 504, 505, 506, 508, 509, 510, 511, 512, 513, 514, 515, 516, 517, 518, 519, 522, 523, 524, 525, 526, 527, 528, 507, 520, 867]}, {"Tumblrs": [529, 530, 531, 532, 533, 534, 535, 536, 537, 538, 539, 540, 541, 542, 543, 544, 545, 546, 547, 548, 549]}, {"Photo Blogs": [550, 551, 552, 553, 554, 555, 556]}, {"Travel": [558, 559, 557]}, 943, {"Link Blogs": [467, 468, 469, 470]}, {"People": [471, 472, 473, 474, 475, 476, 477, 478, 479, 480, 481, 482, 483, 484, 485, 486, 487, 488, 490, 491, 492, 493, 494, 495, 496, 497, 498, 499, 500, 501, 502, 504, 505, 506, 508, 509, 510, 511, 512, 513, 514, 515, 516, 517, 518, 519, 522, 523, 525, 526, 527, 528]}, {"Tumblrs": [529, 530, 531, 532, 533, 534, 535, 536, 537, 538, 539, 540, 541, 542, 543, 544, 545, 546, 547, 548, 549]}, {"Photo Blogs": [550, 551, 552, 553, 554, 555, 556]}, {"Travel": [558, 559]}]}, {"Code": [560, 561, 562, 563, 564, 565, 566, 567, 568, 569, 570, 571, 572, 573, 574, 575, 576, 577, 578, 579, 580, 581, 582, 583]}, {"Cooking": [584, 585, 586, 587, 588, 589, 590, 591, 592, 593, 594, 595, 596, 597, 873, 953]}, {"Meta": [598, 599, 600, 601, 602, 603, 604, 605, 606, 607, 608]}, {"New York": [609, 610, 611, 612, 613, 614]}, {"San Francisco": [615, 616, 617, 618, 619, 620, 621, 622, 623, 624, 625, 626, 627, 628, 629, 630, 631, 632, 633, 634, 875]}, {"Tech": [635, 636, 637, 638, 639, 640, 641, 642, 643, 644, 645, 646, 647, 648, 649, 650, 651, 652, 653, 654, 655, 656, 657, 658, 659, 660, 184, 661, 662, 663, 664, 665, 666]}, {"Comics & Cartoons": [667, 668, 669, 670, 671, 672, 673, 63, 674, 675, 676, 677, 678, 679, 680, 681, 682, 109, 683, 684, 685, 958]}, {"Hardware": [686, 687, 688, 689, 690, 691, 692]}, {"Wood": []}, {"Newsletters": [693, 694, 695, 696, 697, 698, 699, 700, 701, 702, 703, 704, 705, 706, 707, 708, 709, 710, 711, 712, 713, 714, 715, 716, 717, 724, 719, 720, 721, 722, 723, 725, 727, 728, 729, 730, 731, 732, 733, 734, 735, 736, 737, 738, 739, 740, 741, 742, 743, 744, 745, 746, 747, 748, 749, 750, 751, 752, 753, 754, 755, 756, 757, 758, 759, 760, 761, 762, 763, 764, 765, 766, 767, 768, 769, 770, 771, 772, 773, 774, 775, 776, 777, 778, 779, 780, 781, 782, 783, 895]}, {"Woodworking": [784, 785, 786, 787, 788, 789, 790, 791, 792, 793]}, {"Twitter": [794, 795, 796, 797, 798, 799, 800, 801, 802, 803, 804, 805, 806, 807, 838, 915]}, {"News": [808, 809, 810, 811, 812, 813, 814, 815, 816, 817]}, {"Home": [818, 819, 820, 821, 822, 823]}, {"Facebook": [824, 825, 826]}, {"Art": [827, 828]}, {"Science": [403, 404, 405, 401, 402]}, {"Boston": [829, 830]}, {"mobility": [831, 832, 833, 834, 835, 836, 837, 963]}, {"Biking": []}, {"A Muted Folder": [1]}, 1, {"Any Broken Feeds": [916]}, {"Any Broken Feeds, Although Some of These Work Fine": [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 840, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 841, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 842, 50, 51, 52, 53, 54, 843, 56, 57, 58, 59, 60, 61, 62, 63, 844, 917, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 918, 130, 131, 132, 846, 134, 135, 136, 919, 138, 139, 140, 141, 142, 143, 144, 145, 847, 147, 848, 149, 150, 151, 152, 153, 154, 849, 156, 157, 158, 936, 160, 850, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 1, 185, 186, 187, 188, 189, 851, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 852, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 853, 243, 854, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255, 256, 257, 258, 259, 260, 261, 262, 263, 264, 265, 266, 267, 856, 269, 270, 271, 272, 273, 274, 275, 276, 277, 278, 279, 939, 281, 282, 283, 284, 285, 940, 287, 288, 289, 857, 291, 292, 293, 294, 295, 296, 297, 298, 299, 300, 301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 311, 312, 313, 314, 315, 316, 317, 318, 319, 320, 321, 322, 323, 324, 325, 326, 327, 328, 329, 330, 331, 332, 333, 334, 335, 336, 337, 338, 339, 340, 341, 342, 343, 344, 345, 346, 347, 348, 349, 350, 351, 352, 858, 354, 355, 859, 357, 358, 359, 360, 361, 362, 363, 364, 365, 366, 367, 368, 369, 370, 371, 372, 373, 374, 860, 376, 377, 378, 379, 380, 381, 382, 383, 384, 385, 386, 387, 388, 389, 390, 391, 392, 393, 394, 395, {"Ubuntu": [396, 397, 398, 399, 400]}, {"Science": [401, 402, 403, 404, 405]}, {"Music": [406, 407, 408, 409, 410, 411, 412]}, {"NYTimes": [413]}, {"Test": [414]}, {"Organizer": [415, 416, 417]}, {"Adult": [418, 419, 861, 421]}, {"Test": []}, 422]}]'
        usf.save()
        dupe_folders = usf.folders
        usf.compact()
        compact_folders = usf.folders

        self.assertNotEquals(dupe_folders, compact_folders)
    
    def test_compact_user_subscription_folders2(self):
        usf = UserSubscriptionFolders.objects.get(user=User.objects.all()[0])
        usf.folders = '[2, 3, {"Bloglets": [423, 424, 425]}, {"Blogs": [426, 427, 428, 429, 430, {"Photo Blogs": [550, 551, 552, 553, 554, 555, 556]}, {"Photo Blogs": [551, 552, 553, 554, 555, 556]}, {"Travel": [557, 558]}, {"Travel": [557, 559]}, 943, {"Link Blogs": [467, 468, 469, 470, {"Travel": [557, 558]}, {"Travel": [557, 559]}]}, {"Link Blogs": [467, 468, 469, 470, {"Travel": [557, 558]}, {"Travel": [557, 559, 558]}]}]}]'
        usf.save()
        dupe_folders = usf.folders
        usf.compact()
        compact_folders = usf.folders

        self.assertNotEquals(dupe_folders, compact_folders)
