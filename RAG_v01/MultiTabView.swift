//
//  MultiTabView.swift
//  RAG_v01
//
//  Created by Danika Gupta on 11/4/23.
//

import SwiftUI

struct MultiTabView: View {
    var body: some View {
        TabView{
            Tab1View()
                .tabItem{
                    Label("Web page",systemImage: "eyes.inverse")
                }
            ChatGPTView(vm: ViewModel(api: ChatGPTAPI(apiKey: getOpenAIAPIKey())))
                .tabItem{
                    Label("Chat",systemImage: "list.number")
                }
            Tab3View()
                .tabItem{
                    Label("Tab 3",systemImage: "keyboard")
                }
        }
    }
    
    func getOpenAIAPIKey() -> String {
        let key = "OPENAI_API_KEY"
        // Get the path of Secrets.plist file
             guard let path = Bundle.main.path(forResource: "Secret", ofType: "plist") else {
                 fatalError("Couldn't find file 'Secret.plist'.")
             }
             
             // Load the contents of the file into a data dictionary
             let url = URL(fileURLWithPath: path)
             guard let data = try? Data(contentsOf: url),
                   let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
                 fatalError("Couldn't load 'Secrets.plist'.")
             }
             
             // Access the value by key
             guard let value = plist[key] as? String else {
                 fatalError("Couldn't find key '\(key)' in 'Secrets.plist'.")
             }
             
             return value
    }
}

struct Tab1View: View {
    var body: some View {
        Text("Page 1")
            .font(.largeTitle)
            .multilineTextAlignment(.center)
            .edgesIgnoringSafeArea(/*@START_MENU_TOKEN@*/.all/*@END_MENU_TOKEN@*/)
    }
}

struct Tab2View: View {
    var body: some View {
        Text("Page 2")
    }
}

struct Tab3View: View {
    var body: some View {
        Text("Page 3")
    }
}

struct MultiTabView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            MultiTabView()
        }
    }
}
