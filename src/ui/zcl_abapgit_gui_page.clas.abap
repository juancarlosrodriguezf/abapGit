class zcl_abapgit_gui_page definition public abstract create public.

  public section.
    interfaces:
      zif_abapgit_gui_renderable,
      zif_abapgit_gui_event_handler,
      zif_abapgit_gui_error_handler.

    constants:
      " You should remember that these actions are handled in the UI.
      " Have a look at the JS file.
      begin of c_global_page_action,
        showhotkeys type string value `showHotkeys` ##NO_TEXT,
      end of c_global_page_action.

    class-methods:
      get_global_hotkeys
        returning
          value(rt_hotkey) type zif_abapgit_gui_page_hotkey=>tty_hotkey_with_name.

    methods:
      constructor.

  protected section.
    types: begin of ty_control,
             redirect_url type string,
             page_title   type string,
             page_menu    type ref to zcl_abapgit_html_toolbar,
           end of  ty_control.

    types: begin of ty_event,
             method type string,
             name   type string,
           end of  ty_event.

    types: tt_events type standard table of ty_event with default key.

    data: ms_control type ty_control.

    methods render_content abstract
      returning value(ro_html) type ref to zcl_abapgit_html
      raising   zcx_abapgit_exception.

    methods get_events
      returning value(rt_events) type tt_events
      raising   zcx_abapgit_exception.

    methods render_event_as_form
      importing is_event       type ty_event
      returning value(ro_html) type ref to zcl_abapgit_html
      raising   zcx_abapgit_exception.

    methods scripts
      returning value(ro_html) type ref to zcl_abapgit_html
      raising   zcx_abapgit_exception.

  private section.
    data: mo_settings         type ref to zcl_abapgit_settings,
          mt_hotkeys          type zif_abapgit_gui_page_hotkey=>tty_hotkey_with_name,
          mx_error            type ref to zcx_abapgit_exception,
          mo_exception_viewer type ref to zcl_abapgit_exception_viewer.
    methods html_head
      returning value(ro_html) type ref to zcl_abapgit_html.

    methods title
      returning value(ro_html) type ref to zcl_abapgit_html.

    methods footer
      returning value(ro_html) type ref to zcl_abapgit_html.

    methods redirect
      returning value(ro_html) type ref to zcl_abapgit_html.

    methods link_hints
      importing
        io_html type ref to zcl_abapgit_html
      raising
        zcx_abapgit_exception.

    methods insert_hotkeys_to_page
      importing
        io_html type ref to zcl_abapgit_html
      raising
        zcx_abapgit_exception.

    methods render_hotkey_overview
      returning
        value(ro_html) type ref to zcl_abapgit_html
      raising
        zcx_abapgit_exception.

    methods call_browser
      importing
        iv_url type csequence
      raising
        zcx_abapgit_exception.

    methods define_hotkeys
      returning
        value(rt_hotkeys) type zif_abapgit_gui_page_hotkey=>tty_hotkey_with_name
      raising
        zcx_abapgit_exception.

    methods get_default_hotkeys
      returning
        value(rt_default_hotkeys) type zif_abapgit_gui_page_hotkey=>tty_hotkey_with_name.

    methods render_error_message_box
      returning
        value(ro_html) type ref to zcl_abapgit_html
      raising
        zcx_abapgit_exception.

endclass.



class zcl_abapgit_gui_page implementation.


  method call_browser.

    cl_gui_frontend_services=>execute(
      exporting
        document               = |{ iv_url }|
      exceptions
        cntl_error             = 1
        error_no_gui           = 2
        bad_parameter          = 3
        file_not_found         = 4
        path_not_found         = 5
        file_extension_unknown = 6
        error_execute_failed   = 7
        synchronous_failed     = 8
        not_supported_by_gui   = 9
        others                 = 10 ).

    if sy-subrc <> 0.
      zcx_abapgit_exception=>raise_t100( ).
    endif.

  endmethod.


  method constructor.

    mo_settings = zcl_abapgit_persist_settings=>get_instance( )->read( ).

  endmethod.


  method define_hotkeys.

    data: lo_settings             type ref to zcl_abapgit_settings,
          lt_user_defined_hotkeys type zif_abapgit_definitions=>tty_hotkey.

    field-symbols: <ls_hotkey>              type zif_abapgit_gui_page_hotkey=>ty_hotkey_with_name,
                   <ls_user_defined_hotkey> like line of lt_user_defined_hotkeys.

    rt_hotkeys = get_default_hotkeys( ).

    " Override default hotkeys with user defined
    lo_settings = zcl_abapgit_persist_settings=>get_instance( )->read( ).
    lt_user_defined_hotkeys = lo_settings->get_hotkeys( ).

    loop at rt_hotkeys assigning <ls_hotkey>.

      read table lt_user_defined_hotkeys assigning <ls_user_defined_hotkey>
                                         with table key action
                                         components action = <ls_hotkey>-action.
      if sy-subrc = 0.
        <ls_hotkey>-hotkey = <ls_user_defined_hotkey>-hotkey.
      elseif lines( lt_user_defined_hotkeys ) > 0.
        " User removed the hotkey
        delete table rt_hotkeys from <ls_hotkey>.
      endif.

    endloop.

  endmethod.


  method footer.

    create object ro_html.

    ro_html->add( '<div id="footer">' ).                    "#EC NOTEXT

    ro_html->add( zcl_abapgit_html=>a( iv_txt = '<img src="img/logo" alt="logo">'
                                       iv_id  = 'abapGitLogo'
                                       iv_act = zif_abapgit_definitions=>c_action-abapgit_home ) ).
    ro_html->add( '<table class="w100"><tr>' ).             "#EC NOTEXT

    ro_html->add( '<td class="w40"></td>' ).                "#EC NOTEXT
    ro_html->add( |<td><span class="version">{ zif_abapgit_version=>gc_abap_version }</span></td>| ). "#EC NOTEXT
    ro_html->add( '<td id="debug-output" class="w40"></td>' ). "#EC NOTEXT

    ro_html->add( '</tr></table>' ).                        "#EC NOTEXT
    ro_html->add( '</div>' ).                               "#EC NOTEXT

  endmethod.


  method get_default_hotkeys.

    data: lt_page_hotkeys like mt_hotkeys.

    rt_default_hotkeys = get_global_hotkeys( ).

    try.
        call method me->('ZIF_ABAPGIT_GUI_PAGE_HOTKEY~GET_HOTKEY_ACTIONS')
          receiving
            rt_hotkey_actions = lt_page_hotkeys.

        insert lines of lt_page_hotkeys into table rt_default_hotkeys.

      catch cx_root.
        " Current page doesn't implement hotkey interface, do nothing
    endtry.

  endmethod.


  method get_events.

    " Return actions you need on your page.

  endmethod.


  method get_global_hotkeys.

    " these are the global shortcuts active on all pages

    data: ls_hotkey_action like line of rt_hotkey.

    ls_hotkey_action-name   = |Show hotkeys help|.
    ls_hotkey_action-action = c_global_page_action-showhotkeys.
    ls_hotkey_action-hotkey = |?|.
    insert ls_hotkey_action into table rt_hotkey.

  endmethod.


  method html_head.

    create object ro_html.

    ro_html->add( '<head>' ).                               "#EC NOTEXT

    ro_html->add( '<meta http-equiv="content-type" content="text/html; charset=utf-8">' ). "#EC NOTEXT
    ro_html->add( '<meta http-equiv="X-UA-Compatible" content="IE=11,10,9,8" />' ). "#EC NOTEXT

    ro_html->add( '<title>abapGit</title>' ).               "#EC NOTEXT
    ro_html->add( '<link rel="stylesheet" type="text/css" href="css/common.css">' ).
    ro_html->add( '<link rel="stylesheet" type="text/css" href="css/ag-icons.css">' ).

    " Themes
    ro_html->add( '<link rel="stylesheet" type="text/css" href="css/theme-default.css">' ). " Theme basis
    case mo_settings->get_ui_theme( ).
      when zcl_abapgit_settings=>c_ui_theme-dark.
        ro_html->add( '<link rel="stylesheet" type="text/css" href="css/theme-dark.css">' ).
      when zcl_abapgit_settings=>c_ui_theme-belize.
        ro_html->add( '<link rel="stylesheet" type="text/css" href="css/theme-belize-blue.css">' ).
    endcase.

    ro_html->add( '<script type="text/javascript" src="js/common.js"></script>' ). "#EC NOTEXT

    case mo_settings->get_icon_scaling( ). " Enforce icon scaling
      when mo_settings->c_icon_scaling-large.
        ro_html->add( '<style>.icon { font-size: 200% }</style>' ).
      when mo_settings->c_icon_scaling-small.
        ro_html->add( '<style>.icon.large { font-size: inherit }</style>' ).
    endcase.

    ro_html->add( '<style>.myClass{ zoom: 70% }</style>' ).

    ro_html->add( '</head>' ).                              "#EC NOTEXT

  endmethod.


  method insert_hotkeys_to_page.

    data: lv_json type string.

    field-symbols: <ls_hotkey> like line of mt_hotkeys.

    lv_json = `{`.

    loop at mt_hotkeys assigning <ls_hotkey>.

      if sy-tabix > 1.
        lv_json = lv_json && |,|.
      endif.

      lv_json = lv_json && |  "{ <ls_hotkey>-hotkey }" : "{ <ls_hotkey>-action }" |.

    endloop.

    lv_json = lv_json && `}`.

    io_html->add( |setKeyBindings({ lv_json });| ).

  endmethod.


  method link_hints.

    data: lv_link_hint_key type char01.

    lv_link_hint_key = mo_settings->get_link_hint_key( ).

    if mo_settings->get_link_hints_enabled( ) = abap_true and lv_link_hint_key is not initial.

      io_html->add( |activateLinkHints("{ lv_link_hint_key }");| ).
      io_html->add( |setInitialFocusWithQuerySelector('a span', true);| ).
      io_html->add( |enableArrowListNavigation();| ).

    endif.

  endmethod.


  method redirect.

    create object ro_html.

    ro_html->add( '<!DOCTYPE html>' ).                      "#EC NOTEXT
    ro_html->add( '<html>' ).                               "#EC NOTEXT
    ro_html->add( '<head>' ).                               "#EC NOTEXT
    ro_html->add( |<meta http-equiv="refresh" content="0; url={ ms_control-redirect_url }">| ). "#EC NOTEXT
    ro_html->add( '</head>' ).                              "#EC NOTEXT
    ro_html->add( '</html>' ).                              "#EC NOTEXT

  endmethod.


  method render_error_message_box.

    " You should remember that the we have to instantiate ro_html even
    " it's overwritten further down. Because ADD checks whether it's
    " bound.
    create object ro_html.

    " You should remember that we render the message panel only
    " if we have an error.
    if mx_error is not bound.
      return.
    endif.

    ro_html = zcl_abapgit_gui_chunk_lib=>render_error_message_box( mx_error ).

    " You should remember that the exception viewer dispatches the events of
    " error message panel
    create object mo_exception_viewer
      exporting
        ix_error = mx_error.

    " You should remember that we render the message panel just once
    " for each exception/error text.
    clear:
      mx_error.

  endmethod.


  method render_event_as_form.

    create object ro_html.
    ro_html->add(
      |<form id='form_{ is_event-name }' method={ is_event-method } action='sapevent:{ is_event-name }'></from>| ).

  endmethod.


  method render_hotkey_overview.

    ro_html = zcl_abapgit_gui_chunk_lib=>render_hotkey_overview( me ).

  endmethod.


  method scripts.

    create object ro_html.

    link_hints( ro_html ).
    insert_hotkeys_to_page( ro_html ).

    ro_html->add( 'var gGoRepoPalette = new CommandPalette(enumerateTocAllRepos, {' ).
    ro_html->add( '  toggleKey: "F2",' ).
    ro_html->add( '  hotkeyDescription: "Go to repo ..."' ).
    ro_html->add( '});' ).

    ro_html->add( 'var gCommandPalette = new CommandPalette(enumerateToolbarActions, {' ).
    ro_html->add( '  toggleKey: "F1",' ).
    ro_html->add( '  hotkeyDescription: "Command ..."' ).
    ro_html->add( '});' ).

  endmethod.


  method title.

    create object ro_html.

    ro_html->add( '<div id="header">' ).                    "#EC NOTEXT
    ro_html->add( '<table class="w100"><tr>' ).             "#EC NOTEXT

    ro_html->add( |<td class="logo">{
                  zcl_abapgit_html=>a( iv_txt = '<img src="img/logo" alt="logo">'
                                       iv_id  = 'abapGitLogo'
                                       iv_act = zif_abapgit_definitions=>c_action-abapgit_home )
                  }</td>| ).                                "#EC NOTEXT

    ro_html->add( |<td><span class="page_title"> &#x25BA; { ms_control-page_title }</span></td>| ). "#EC NOTEXT

    if ms_control-page_menu is bound.
      ro_html->add( '<td class="right">' ).                 "#EC NOTEXT
      ro_html->add( ms_control-page_menu->render( iv_right = abap_true ) ).
      ro_html->add( '</td>' ).                              "#EC NOTEXT
    endif.

    ro_html->add( '</tr></table>' ).                        "#EC NOTEXT
    ro_html->add( '</div>' ).                               "#EC NOTEXT

  endmethod.


  method zif_abapgit_gui_error_handler~handle_error.

    mx_error = ix_error.
    rv_handled = abap_true.

  endmethod.


  method zif_abapgit_gui_event_handler~on_event.

    case iv_action.
      when zif_abapgit_definitions=>c_action-url.

        call_browser( iv_getdata ).
        ev_state = zcl_abapgit_gui=>c_event_state-no_more_act.

      when zif_abapgit_definitions=>c_action-goto_source.

        if mo_exception_viewer is bound.
          mo_exception_viewer->goto_source( ).
        endif.
        ev_state = zcl_abapgit_gui=>c_event_state-no_more_act.

      when zif_abapgit_definitions=>c_action-show_callstack.

        if mo_exception_viewer is bound.
          mo_exception_viewer->show_callstack( ).
        endif.
        ev_state = zcl_abapgit_gui=>c_event_state-no_more_act.

      when zif_abapgit_definitions=>c_action-goto_message.

        if mo_exception_viewer is bound.
          mo_exception_viewer->goto_message( ).
        endif.
        ev_state = zcl_abapgit_gui=>c_event_state-no_more_act.

      when others.

        ev_state = zcl_abapgit_gui=>c_event_state-not_handled.

    endcase.

  endmethod.


  method zif_abapgit_gui_renderable~render.

    data: lo_script type ref to zcl_abapgit_html,
          lt_events type tt_events.

    field-symbols:
          <ls_event> like line of lt_events.

    " Redirect
    if ms_control-redirect_url is not initial.
      ri_html = redirect( ).
      return.
    endif.

    mt_hotkeys = define_hotkeys( ).

    " Real page
    create object ri_html type zcl_abapgit_html.

    ri_html->add( '<!DOCTYPE html>' ).                      "#EC NOTEXT
    ri_html->add( '<html class="myClass">' ).               "#EC NOTEXT
    ri_html->add( html_head( ) ).
    ri_html->add( '<body>' ).                                "#EC NOTEXT
    ri_html->add( title( ) ).
    ri_html->add( render_hotkey_overview( ) ).
    ri_html->add( render_content( ) ).
    ri_html->add( render_error_message_box( ) ).

    lt_events = me->get_events( ).
    loop at lt_events assigning <ls_event>.
      ri_html->add( render_event_as_form( <ls_event> ) ).
    endloop.

    ri_html->add( footer( ) ).
    ri_html->add( '</body>' ).                              "#EC NOTEXT

    lo_script = scripts( ).

    if lo_script is bound and lo_script->is_empty( ) = abap_false.
      ri_html->add( '<script type="text/javascript">' ).
      ri_html->add( lo_script ).
      ri_html->add( 'confirmInitialized();' ).
      ri_html->add( '</script>' ).
    endif.

    ri_html->add( '</html>' ).                              "#EC NOTEXT

  endmethod.
endclass.
