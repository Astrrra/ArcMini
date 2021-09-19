//
//  TimelineDayView.swift
//  Arc Mini
//
//  Created by Matt Greenfield on 6/3/20.
//  Copyright © 2020 Matt Greenfield. All rights reserved.
//

import SwiftUI
import LocoKit

struct TimelineDayView: View {

    @ObservedObject var timelineSegment: TimelineSegment

    init(timelineSegment: TimelineSegment) {
        self.timelineSegment = timelineSegment
        UITableViewCell.appearance().selectionStyle = .none
        UITableView.appearance().backgroundColor = UIColor(named: "background")
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            List {
                let top = Rectangle()
                    .frame(height: 20).opacity(0)
                    .listRowInsets(EdgeInsets())
                    .onAppear { TimelineState.highlander.timelineScrolledToTop = true }
                    .onDisappear { TimelineState.highlander.timelineScrolledToTop = false }
                
                if #available(iOS 15.0, *) {
                    top.listRowSeparator(.hidden)
                } else {
                    top
                }
                
                ForEach(filteredListItems) { displayItem in
                    let box = listBox(for: displayItem).onAppear {
                        if let visit = displayItem.timelineItem as? ArcVisit, visit.isWorthKeeping {
                            visit.findAPlace()
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    
                    if #available(iOS 15.0, *) {
                        box.listRowSeparator(.hidden)
                    } else {
                        box
                    }
                }
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 0)
            Rectangle().fill(Color("brandSecondary10")).frame(width: 0.5).edgesIgnoringSafeArea(.all)
        }
        .navigationBarHidden(true)
        .onAppear { updateForAppearDisappear() }
        .onDisappear { updateForAppearDisappear() }
        .onReceive(TimelineState.highlander.$currentCardIndex) { _ in
            updateForAppearDisappear()
        }
        .background(Color("background"))
    }

    var filteredListItems: [DisplayItem] {
        var displayItems: [DisplayItem] = []
        
        var previousWasThinker = false
        for item in timelineSegment.timelineItems.reversed() {
            if item.dateRange == nil { continue }
            if item.invalidated { continue }
            
            let useThinkers = RecordingManager.store.processing || activeItems.contains(item) || item.isMergeLocked

            if item.isWorthKeeping {
                displayItems.append(DisplayItem(timelineItem: item))
                previousWasThinker = false
                
            } else if useThinkers && !previousWasThinker {
                displayItems.append(DisplayItem(thinkerId: item.itemId))
                previousWasThinker = true
            }
        }
        
        return displayItems
    }

    var isToday: Bool {
        return timelineSegment.dateRange?.contains(Date()) == true
    }

    // the items inside the recorder's processing boundary
    var activeItems: [TimelineItem] {
        if isToday, !LocomotionManager.highlander.recordingState.isSleeping, let currentItem = RecordingManager.recorder.currentItem {
            return TimelineProcessor.itemsToProcess(from: currentItem)
        }
        return []
    }

    func listBox(for displayItem: DisplayItem) -> some View {

        // show a "thinking" item for shitty stuff that's still processing or can't be processed yet
        guard let item = displayItem.timelineItem else {
            let box = ThinkingListBox()
            return AnyView(box)
        }
        
        let boxStack = ZStack {
            NavigationLink(destination: ItemDetailsView(timelineItem: item)) {}
            self.timelineItemBox(for: item)
                .onAppear {
                    if self.timelineSegment == TimelineState.highlander.visibleTimelineSegment {
                        TimelineState.highlander.visibleItems.insert(item)
                        updateSelectedItems()
                    }
                }.onDisappear {
                    if self.timelineSegment == TimelineState.highlander.visibleTimelineSegment {
                        TimelineState.highlander.visibleItems.remove(item)
                        updateSelectedItems()
                    }
                }
        }
        
        return AnyView(boxStack)
    }

    func timelineItemBox(for item: TimelineItem) -> some View {
        if let visit = item as? ArcVisit {
            let box = VisitListBox(visit: visit)
            return AnyView(box)
        }
        if let path = item as? ArcPath {
            let box = PathListBox(path: path)
            return AnyView(box)
        }
        fatalError("nah")
    }
    
    // MARK: -
    
    func updateForAppearDisappear() {
        guard TimelineState.highlander.visibleDateRange == timelineSegment.dateRange else {
            timelineSegment.stopUpdating()
            return
        }
        timelineSegment.startUpdating()
        MapState.highlander.selectedItems.removeAll()
        MapState.highlander.itemSegments.removeAll()
        TimelineState.highlander.visibleItems.removeAll()
        TimelineState.highlander.backButtonHidden = true
        TimelineState.highlander.updateTodayButton()
        TimelineState.highlander.mapHeightPercent = TimelineState.rootMapHeightPercent
    }
    
    func updateSelectedItems() {
        if TimelineState.highlander.timelineScrolledToTop {
            MapState.highlander.selectedItems = [] // zoom to all items when scrolled to top
        } else {
            MapState.highlander.selectedItems = TimelineState.highlander.visibleItems
        }
    }

    // MARK: -
    
    struct DisplayItem: Identifiable {
        var id: UUID
        var timelineItem: TimelineItem?
        
        init(timelineItem: TimelineItem? = nil, thinkerId: UUID? = nil) {
            self.timelineItem = timelineItem
            if let timelineItem = timelineItem {
                id = timelineItem.itemId
            } else {
                id = thinkerId!
            }
        }
    }
    
}
