# Contract: View ↔ View Model Bindings

This feature has no external interface. The contract here is between each view and its view model: what a view may bind to or call. Views hold no hand-written `Binding(get:set:)` for view-model state and no presentation wrapper types (SC-003).

| View | Binds / calls | View-model member |
|---|---|---|
| `BrowseView` | reads | `browse.forecast` (detail column, `.id(forecast.place)`) |
| `SearchView` | `$browse.search.query` (searchable), `.task(id:)` → `search.search()` after 300 ms | `SearchViewModel.query`, `search()` (debounce stays in the view, FR-008) |
| `SearchView` | `List(places, selection: $browse.selection)` | `BrowseViewModel.selection` |
| `SearchView` | Retry | `SearchViewModel.retry()` |
| `ForecastView` | `.task` | `ForecastViewModel.loadIfNeeded()` |
| `ForecastView` | `.sheet(item: $model.presentedDay)` | `ForecastViewModel.presentedDay` |
| `ActivitySection` (via `onSelect`) | day tap | `ForecastViewModel.showDetail(for:)` |
| `ForecastView` | Retry | `ForecastViewModel.retry()` |

These stay view-local, as transient UI state: `BrowseView.columnVisibility`, `ForecastView`'s `@Namespace` for the zoom transition, and `DayDetailView`'s `dismiss`.
