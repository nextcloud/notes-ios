# Code Blocks

The following is a code block _without_ language hint:

```
./occ app:install notes
```

The following is a code block _with_ language hint:

```sh
./occ app:install notes
```

The follwing is a larger Swift code block:

```swift
import SwiftUI
import SwiftData

@main
struct NotesApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
```