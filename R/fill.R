#' Fill in missing values with previous or next value
#'
#' @description
#' Fills missing values in the selected columns using the next or previous entry. Can be done by group.
#'
#' Supports tidyselect
#'
#' @param .df A data.frame or data.table
#' @param ... A selection of columns. `tidyselect` compatible.
#' @param .direction Direction in which to fill missing values.
#' Currently "down" (the default), "up", "downup" (first down then up), or "updown" (first up and then down)
#' @param .by Columns to group by when filling should be done by group
#'
#' @export
#' @md
#'
#' @examples
#' test_df <- tidytable(
#'   x = c(NA, NA, NA, 4:10),
#'   y = c(1:6, NA, 8, NA, 10),
#'   z = c(rep("a", 8), rep("b", 2)))
#'
#' test_df %>%
#'   fill.(x, y, .by = z)
#'
#' test_df %>%
#'   fill.(x, y, .by = z, .direction = "downup")
fill. <- function(.df, ...,
                  .direction = c("down", "up", "downup", "updown"),
                  .by = NULL) {
  UseMethod("fill.")
}

#' @export
fill..data.frame <- function(.df, ...,
                             .direction = c("down", "up", "downup", "updown"),
                             .by = NULL) {

  .df <- as_tidytable(.df)

  .by <- enquo(.by)

  .direction <- arg_match(.direction)

  select_cols <- select_dots_chr(.df, ...)

  subset_data <- .df[, ..select_cols]

  numeric_flag <- map_lgl.(subset_data, is.numeric)

  with_by <- !quo_is_null(.by)

  if (with_by) {
    .df <- copy(.df)

    col_order <- names(.df)
  } else {
    .df <- shallow(.df)
  }

  .by <- select_vec_chr(.df, !!.by)

  if (all(numeric_flag)) {

    # Use data.table::nafill() if all numeric
    if (.direction %in% c("down", "up")) {
      .type <- switch(.direction, "down" = "locf", "up" = "nocb")

      .df[, (select_cols) := lapply(.SD, nafill, .type), .SDcols = select_cols, by = .by]

    } else if (.direction == "downup") {
      .df[, (select_cols) := lapply(.SD, function(.x) nafill(nafill(.x, type = "locf"), type = "nocb")),
          .SDcols = select_cols, by = .by]
    } else {
      .df[, (select_cols) := lapply(.SD, function(.x) nafill(nafill(.x, type = "nocb"), type = "locf")),
          .SDcols = select_cols, by = .by]
    }

  } else {

    # Use vctrs::vec_fill_missing() if there are any character cols
    .df[, (select_cols) := lapply(.SD, vec_fill_missing, direction = .direction),
        .SDcols = select_cols, by = .by]
  }

  if (with_by) setcolorder(.df, col_order)

  .df[]
}

globalVariables("..select_cols")
