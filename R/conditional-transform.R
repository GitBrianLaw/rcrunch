#' Conditional transformation
#'
#' Create a new variable that has values when specific conditions are met.
#' Conditions are specified using a series of formulas: the right-hand side is
#' the condition that must be true (a `CrunchLogicalExpr`) and the left-hand
#' side is where to get the value if the condition on the right-hand side is
#' true. This is commonly a Crunch variable but may be a string or numeric
#' value, depending on the type of variable you're constructing.
#'
#' The type of the new variable can depend on the type(s) of the source
#' variable(s).  By default (`type=NULL`), the type of the new variable will be
#' the type of all of the source variables (that is, if all of the source
#' variables are text, the new variable type will be text, if all of the
#' source variables are categorical, the new variable will be categorical).
#' If there are multiple types in the source variables, the result will be a
#' text variable. The default behavior can be overridden by specifying
#' `type = "categorical"`, `"text"`, or `"numeric"`.
#'
#' `conditionalTransform` is similar to `makeCaseVariable`; however,
#' `conditionalTransform` can use other Crunch variables as a source of a
#' variable, whereas, `makeCaseVariable` can only use characters. This
#' additional power comes at a cost: `makeCaseVariable` can be executed
#' entirely on Crunch servers, so no data needs to be downloaded or uploaded
#' to/from the local R session. `conditionalTransform` on the other hand will
#' download the data necessary to construct the new variable.
#'
#' @param ... a list of cases to evaluate as well as other
#' properties to pass about the case variable (i.e. alias, description)
#' @param data a Crunch dataset object to use
#' @param else_condition a default value to use if none of the conditions are
#' true (default: `NA`)
#' @param type a character that is either "categorical", "text", "numeric" what
#'  type of output should be returned? If `NULL`, the type of the source
#'  variable will be used. (default: `NULL`) The source variables will be
#'  converted to this type if necessary.
#' @param categories a vector of characters if `type="categorical"`, these are
#' all of the categories that should be in the resulting variable, in the order
#' they should be in the resulting variable or a set of Crunch categories.
#'
#' @return a Crunch `VariableDefinition`
#' @examples
#' \dontrun{
#'
#' ds$cat_opinion <- conditionalTransform(pet1 == 'Cat' ~ Opinion1,
#'                                        pet2 == 'Cat' ~ Opinion2,
#'                                        pet3 == 'Cat' ~ Opinion3,
#'                                        data = ds,
#'                                        name = "Opinion of Cats")
#' }
#' @export
conditionalTransform <- function (..., data, else_condition=NA, type=NULL,
                                  categories=NULL) {
    dots <- list(...)
    is_formula <- function (x) inherits(x, "formula")
    formulas <- Filter(is_formula, dots)
    var_def <- Filter(Negate(is_formula), dots)

    if (length(formulas) == 0) {
        halt("no conditions have been supplied; please supply formulas as conditions.")
    }

    if (!missing(type) && !type %in% c("categorical", "text", "numeric")){
        halt("type must be either ", dQuote("categorical"), ", ",
             dQuote("text"), ", or ", dQuote("numeric"))
    }

    conditional_vals <- makeConditionalValues(formulas, data, else_condition)
    if (!missing(type)) {
        if (type == "numeric") {
            result <- as.numeric(conditional_vals$values)
        } else {
            result <- as.character(conditional_vals$values)
        }
    } else {
        # determine type
        result <- conditional_vals$values
        type <- conditional_vals$type
    }

    if (type != "categorical" & !is.null(categories)){
        warning("type is not ", dQuote("categorical"), " ignoring ",
                dQuote("categories"))
    }
    var_def$type <- type

    # add categories if necessary
    if (type == "categorical") {
        # if categories are supplied and there are any
        if (missing(categories)) {
            result <- factor(result)
            # make categories from names
            categories <- Categories(data = categoriesFromLevels(levels(result)))
        } else {
            if (!is.categories(categories)) {
                # if categories aren't a Categories object,
                # make categories from names
                categories <- Categories(data = categoriesFromLevels(categories))
            }

            uni_results <- unique(result[!is.na(result)])
            results_not_categories <- !uni_results %in% names(categories)
            if (any(results_not_categories)) {
                halt("there were categories in the results (",
                     serialPaste(uni_results[results_not_categories]),
                     ") that were not specified in categories")
            }
            result <- factor(result, levels = names(categories))
        }
        categories <- ensureNoDataCategory(categories)
        # make a category list to send with VariableDefinition and then store
        # that and convert values to ids values
        category_list <- categories
        var_def$categories <- category_list
        vals <- as.character(result)
        vals[is.na(vals)] <- "No Data" # na is system default
        var_def$values <- ids(categories[vals])
    } else {
        var_def$values <- result
    }

    class(var_def) <- "VariableDefinition"
    return(var_def)
}

makeConditionalValues <- function (formulas, data, else_condition) {
    n <- length(formulas)
    cases <- vector("list", n)
    values <- vector("list", n)
    for (i in seq_len(n)) {
        formula <- formulas[[i]]
        if (length(formula) != 3) {
            halt("The case provided is not a proper formula: ",
                 deparseAndFlatten(formula))
        }

        cases[[i]] <- evalLHS(formula, data)
        if (!inherits(cases[[i]], "CrunchLogicalExpr")) {
            halt("The left-hand side provided is not a CrunchLogicalExpr: ",
                 LHS_string(formula))
        }
        values[[i]] <- evalRHS(formula, data)
    }

    # setup NAs for as default
    # check all datasets are the same and get the reference from the unique one
    ds_refs <- unlist(unique(lapply(cases, datasetReference)))
    if (length(ds_refs) > 1) {
        halt("There is more than one dataset referenced. Please ",
             "supply only one.")
    }
    n_rows <- nrow(CrunchDataset(crGET(ds_refs)))

    # grab booleans for cases
    case_indices <- lapply(cases, which)

    # deduplicate indices, favoring the first true condition
    case_indices <- lapply(seq_along(case_indices), function(i) {
        setdiff(case_indices[[i]], unlist(case_indices[seq_len(i-1)]))
    })

    # grab the values needed from source variables
    values_to_fill <- Map(function(ind, var) {
        if (inherits(var, c("CrunchVariable", "CrunchExpr"))) {
            # grab the variable contents at inds we take inds after as.vector
            # in case there is a filter applied. If the API allowed for
            # returning values at specific indices, even when a dataset is
            # filtered, this wouldn't be necessary (cf pivotal: #151013797)
            return(as.vector(var)[ind])
        } else {
            # if var isn't a crunch variable or expression, just return var
            return(var)
        }
    }, ind = case_indices, var = values)

    # determine the types before collation (since factor coercion is less than
    # ideal, we need to do this before we collate)
    pre_collation_types <- vapply(values, class, character(1))
    values <- collateValues(values_to_fill, case_indices, else_condition, n_rows)

    if (all(pre_collation_types == "factor")) {
        type <- "categorical"
    } else if (is.numeric(values)) {
        type <- "numeric"
    } else {
        # catch all, in case there are R types like logicals that Crunch would
        # treat as character or categorical
        type <- "text"
    }

    return(list(values = values, type = type))
}

# because factors by default coerce into their IDs, which is almost never what
# we want, we need to do some magic to collate the values together.
collateValues <- function (values_to_fill, case_indices, else_condition,
                           n_rows) {
    result <- rep(else_condition, n_rows)

    # fill values
    for (i in seq_along(case_indices)) {
        vals <- values_to_fill[[i]]

        # change all factors to characters temporarily to avoid accidental
        # coercion to ids (the default if result is not already a factor)
        if (is.factor(vals)) {
            vals <- as.character(vals)
        }

        result[case_indices[[i]]] <- vals
    }

    return(result)
}