module Components.AppHeader exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import App.Model exposing (Model)
import App.Messages exposing 
    (Msg(HomeClick, OpenSigninModal, OpenProfileModal, OpenCotonomaModal, NavigationToggle))


view : Model -> Html Msg
view model =
    div [ id "app-header" ]
        [ div [ class "location" ]
            (case model.cotonoma of
                Nothing -> 
                  [ i [ class "material-icons" ] [ text "home" ]
                  , navigationToggle model
                  ]
                Just cotonoma ->
                  [ a [ class "to-home", onClick HomeClick ] 
                      [ i [ class "material-icons" ] [ text "home" ] ]
                  , i [ class "material-icons" ] [ text "navigate_next" ]
                  , span [ class "cotonoma-name" ] [ text cotonoma.name ]
                  , navigationToggle model
                  ]
            )
        , (case model.session of
            Nothing -> 
                span [] []
            Just session -> 
                a [ class "add-cotonoma", title "Add Cotonoma", onClick OpenCotonomaModal ] 
                    [ i [ class "material-icons" ] [ text "add_circle_outline" ] ] 
          )
        , div [ class "user" ]
            (case model.session of
                Nothing -> 
                    [ a [ title "Sign in", onClick OpenSigninModal ] 
                        [ i [ class "material-icons" ] [ text "perm_identity" ] ] 
                    ]
                Just session -> 
                    [ a [ title "Profile", onClick OpenProfileModal ] 
                        [ img [ class "avatar", src session.avatarUrl ] [] ] 
                    ]
            )
        ]


navigationToggle : Model -> Html Msg
navigationToggle model =
    a 
        [ classList 
            [ ( "toggle-navigation", True )
            , ( "hidden", List.isEmpty model.cotonomas ) 
            ]
        , onClick NavigationToggle
        ] 
        [ i [ class "material-icons" ] 
            [ text 
                (if model.navigationOpen then 
                  "arrow_drop_up" 
                else 
                  "arrow_drop_down" 
                )
            ] 
        ]
