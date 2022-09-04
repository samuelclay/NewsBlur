//
//  FeedDetailViewController.swift
//  NewsBlur
//
//  Created by David Sinclair on 2020-08-27.
//  Copyright © 2020 NewsBlur. All rights reserved.
//

import UIKit

/// List of stories for a feed.
class FeedDetailViewController: FeedDetailObjCViewController {
    enum SectionLayoutKind: Int, CaseIterable {
        /// Feed cells before the story.
        case feedBeforeStory
        
        /// The selected story.
        case selectedStory
        
        /// Feed cells after the story.
        case feedAfterStory
        
        /// Loading cell at the end.
        case loading
    }
    
    var feedColumns: Int {
        guard let pref = UserDefaults.standard.string(forKey: "grid_columns"), let columns = Int(pref) else {
            return 4
        }
        
        return columns
    }
    
    var dataSource: UICollectionViewDiffableDataSource<SectionLayoutKind, Int>! = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        feedCollectionView.collectionViewLayout = createLayout()
        configureDataSource()
    }
    
    @objc override func reload() {
        configureDataSource()
    }
}

extension FeedDetailViewController {
    func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { (sectionIndex: Int,
                                                            layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            
            guard let sectionLayoutKind = SectionLayoutKind(rawValue: sectionIndex) else {
                return nil
            }
            
            let isStory = sectionLayoutKind == .selectedStory
            let columns = isStory ? 1 : self.feedColumns
            
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                  heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
            
            let groupHeight = isStory ?
            NSCollectionLayoutDimension.absolute(1000) :
            NSCollectionLayoutDimension.fractionalWidth(0.4)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                   heightDimension: groupHeight)
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: columns)
            
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 0, trailing: 10)
            
            return section
        }
        
        return layout
    }
}

extension FeedDetailViewController {
    func configureDataSource() {
        let feedCellRegistration = UICollectionView.CellRegistration<FeedDetailCollectionCell, Int> { (cell, indexPath, identifier) in
            cell.contentView.backgroundColor = UIColor.red
            cell.contentView.layer.borderColor = UIColor.black.cgColor
            cell.contentView.layer.borderWidth = 1
            //            cell.contentView.layer.cornerRadius = SectionLayoutKind(rawValue: indexPath.section)! == .feed ? 8 : 0
            
            self.prepareFeedCell(cell, indexPath: indexPath)
        }
        
        let storyCellRegistration = UICollectionView.CellRegistration<StoryPagesCollectionCell, Int> { (cell, indexPath, identifier) in
            //TODO: 🚧
            cell.contentView.backgroundColor = UIColor.blue
            
            self.prepareStoryCell(cell, indexPath: indexPath)
        }
        
        dataSource = UICollectionViewDiffableDataSource<SectionLayoutKind, Int>(collectionView: feedCollectionView) {
            (collectionView: UICollectionView, indexPath: IndexPath, identifier: Int) -> UICollectionViewCell? in
            return SectionLayoutKind(rawValue: indexPath.section)! == .selectedStory ?
            collectionView.dequeueConfiguredReusableCell(using: storyCellRegistration, for: indexPath, item: identifier) : collectionView.dequeueConfiguredReusableCell(using: feedCellRegistration, for: indexPath, item: identifier)
            
        }
        
        var snapshot = NSDiffableDataSourceSnapshot<SectionLayoutKind, Int>()
        
        // +1 for the loading cell.
        let storyCount = Int(appDelegate.storiesCollection.storyLocationsCount) + 1
        
        snapshot.appendSections(SectionLayoutKind.allCases)
        
        if self.messageView.isHidden {
            if storyCount > 1 {
                let selectedIndex = max(appDelegate.storiesCollection.indexOfActiveStory(), 0)
                
                if selectedIndex > 0 {
                    snapshot.appendItems(Array(0..<selectedIndex - 1), toSection: .feedBeforeStory)
                }
                
                snapshot.appendItems([selectedIndex], toSection: .selectedStory)
                
                if selectedIndex < storyCount - 1 {
                    snapshot.appendItems(Array(selectedIndex + 1..<storyCount), toSection: .feedAfterStory)
                }
            }
            
            snapshot.appendItems([0], toSection: .loading)
        }
        
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}
