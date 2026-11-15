import SwiftUI
import WidgetKit

@main
struct JinriWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        PetLiveActivity()
    }
}