#' @name tidy_model_parameters
#' @title Convert `parameters` package output to `tidyverse` conventions
#'
#' @inheritParams parameters::model_parameters
#'
#' @importFrom parameters model_parameters standardize_names
#' @importFrom dplyr select matches rename_all recode contains filter bind_cols
#' @importFrom tidyr fill
#' @importFrom performance r2_bayes
#'
#' @examples
#' model <- lm(mpg ~ wt + cyl, data = mtcars)
#' tidy_model_parameters(model)
#' @export

tidy_model_parameters <- function(model, ...) {
  stats_df <- parameters::model_parameters(model, verbose = FALSE, ...) %>%
    dplyr::select(-dplyr::matches("Difference")) %>%
    parameters::standardize_names(style = "broom") %>%
    dplyr::rename_all(.funs = dplyr::recode, "bayes.factor" = "bf10") %>%
    tidyr::fill(dplyr::matches("^prior|^bf"), .direction = "updown")

  # ------------------------ Bayesian ANOVA designs -------------------------

  if ("method" %in% names(stats_df)) {
    if (stats_df$method[[1]] == "Bayes factors for linear models") {
      # dataframe with posterior estimates for R-squared
      df_r2 <- performance::r2_bayes(model, average = TRUE, ci = stats_df$conf.level[[1]]) %>%
        as_tibble(.) %>%
        parameters::standardize_names(style = "broom") %>%
        dplyr::rename_with(.fn = ~ paste0("r2.", .x), .cols = dplyr::matches("^conf|^comp"))

      # for within-subjects design, retain only marginal component
      if ("r2.component" %in% names(df_r2)) df_r2 %<>% dplyr::filter(r2.component == "conditional")

      # combine everything
      stats_df %<>% dplyr::bind_cols(df_r2)
    }
  }

  as_tibble(stats_df)
}


#' @name tidy_model_effectsize
#' @title Convert `effectsize` package output to `tidyverse` conventions
#'
#' @param data Dataframe returned by `effectsize` functions.
#' @param ... Currently ignored.
#'
#' @importFrom effectsize get_effectsize_label
#' @importFrom purrr compose attr_getter
#' @importFrom dplyr select mutate contains rename_with
#'
#' @examples
#' df <- effectsize::cohens_d(sleep$extra, sleep$group)
#' tidy_model_effectsize(df)
#' @export

tidy_model_effectsize <- function(data, ...) {
  dplyr::bind_cols(
    data %>%
      dplyr::mutate(effectsize = stats::na.omit(effectsize::get_effectsize_label(colnames(.)))[[1]]) %>%
      parameters::standardize_names(style = "broom") %>%
      dplyr::select(-dplyr::contains("term")),
    dplyr::rename_with(get_ci_method(data), ~ paste0("conf.", .x))
  )
}

#' helper to get ci-related info stored as attributes in `effectsize` outputs
#' @noRd

get_ci_method <- purrr::compose(as_tibble, purrr::attr_getter("ci_method"))
