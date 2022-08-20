//
//  GridDetailViewController.swift
//  NewsBlur
//
//  Created by David Sinclair on 2022-08-19.
//  Copyright © 2022 NewsBlur. All rights reserved.
//

import UIKit

/// A view controller to manage the Grid layout.
class GridDetailViewController: UIViewController {
    @IBOutlet var collectionView: UICollectionView!
    
    enum SectionLayoutKind: Int, CaseIterable {
        /// Feed cell kind.
        case feed
        
        /// Story cell kind.
        case story
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
        
        collectionView.collectionViewLayout = createLayout()
        configureDataSource()
    }
}

extension GridDetailViewController {
    func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { (sectionIndex: Int,
                                                            layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            
            guard let sectionLayoutKind = SectionLayoutKind(rawValue: sectionIndex) else {
                return nil
            }
            
            let columns = sectionLayoutKind == .feed ? self.feedColumns : 1
            
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                  heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
            
            let groupHeight = columns == 1 ?
            NSCollectionLayoutDimension.absolute(44) :
            NSCollectionLayoutDimension.fractionalWidth(0.2)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                   heightDimension: groupHeight)
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: columns)
            
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
            
            return section
        }
        
        return layout
    }
}

extension GridDetailViewController {
    func configureDataSource() {
        let feedCellRegistration = UICollectionView.CellRegistration<GridFeedCell, Int> { (cell, indexPath, identifier) in
            //TODO: 🚧
        }
        
        let storyCellRegistration = UICollectionView.CellRegistration<GridStoryCell, Int> { (cell, indexPath, identifier) in
            //TODO: 🚧
            cell.contentView.backgroundColor = UIColor.red
            cell.contentView.layer.borderColor = UIColor.black.cgColor
            cell.contentView.layer.borderWidth = 1
            cell.contentView.layer.cornerRadius = SectionLayoutKind(rawValue: indexPath.section)! == .feed ? 8 : 0
        }
        
        dataSource = UICollectionViewDiffableDataSource<SectionLayoutKind, Int>(collectionView: collectionView) {
            (collectionView: UICollectionView, indexPath: IndexPath, identifier: Int) -> UICollectionViewCell? in
            return SectionLayoutKind(rawValue: indexPath.section)! == .story ?
            collectionView.dequeueConfiguredReusableCell(using: feedCellRegistration, for: indexPath, item: identifier) :
            collectionView.dequeueConfiguredReusableCell(using: storyCellRegistration, for: indexPath, item: identifier)
        }
        
        let itemsPerSection = 10
        var snapshot = NSDiffableDataSourceSnapshot<SectionLayoutKind, Int>()
        
        SectionLayoutKind.allCases.forEach {
            snapshot.appendSections([$0])
            let itemOffset = $0.rawValue * itemsPerSection
            let itemUpperbound = itemOffset + itemsPerSection
            snapshot.appendItems(Array(itemOffset..<itemUpperbound))
        }
        
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

extension GridDetailViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}
