#include <windows.h>
#include <shellapi.h>
#include <commctrl.h>
#include <string>
enum {
    LANG=10, SHOW, SPOOF, RESTORE, PRESET, APPLY, RESTORE_COLOR, ACE_STATUS, ACE_TEST
};
constexpr UINT POLL=71;
struct App {
    HWND w{
    },lang{
    },preset{
    },show{
    },spoof{
    },restore{
    },apply{
    },restoreColor{
    },status{
    },test{
    };
    HANDLE child{
    };
    bool vi=true;
    UINT dpi=96;
    HFONT h1{
    },h2{
    },body{
    },mono{
    };
}
a;
const COLORREF bg=RGB(12,17,15), cardColor=RGB(24,32,27), control=RGB(39,51,42), border=RGB(88,105,75), text=RGB(238,242,230), muted=RGB(170,181,160), lime=RGB(190,224,72), amber=RGB(245,149,47);
std::wstring S(const wchar_t* en,const wchar_t* vi){
    return a.vi?vi:en;
}
int px(int v){
    return MulDiv(v,a.dpi,96);
}
int Msg(const std::wstring&s,UINT f){
    return MessageBoxW(a.w,s.c_str(),L"Delta Ops",f);
}
std::wstring Dir(){
    std::wstring s(32768,L'\0');
    DWORD n=GetModuleFileNameW(nullptr,s.data(),(DWORD)s.size());
    s.resize(n);
    return s.substr(0,s.find_last_of(L"\\/"));
}
std::wstring Ps(){
    wchar_t b[MAX_PATH]{
    };
    GetSystemDirectoryW(b,MAX_PATH);
    return std::wstring(b)+L"\\WindowsPowerShell\\v1.0\\powershell.exe";
}
void font(){
    for(HFONT f:{
        a.h1,a.h2,a.body,a.mono
    })if(f)DeleteObject(f);
    a.h1=CreateFontW(-px(30),0,0,0,FW_BOLD,0,0,0,DEFAULT_CHARSET,0,0,CLEARTYPE_QUALITY,0,L"Segoe UI");
    a.h2=CreateFontW(-px(18),0,0,0,FW_SEMIBOLD,0,0,0,DEFAULT_CHARSET,0,0,CLEARTYPE_QUALITY,0,L"Segoe UI");
    a.body=CreateFontW(-px(16),0,0,0,FW_NORMAL,0,0,0,DEFAULT_CHARSET,0,0,CLEARTYPE_QUALITY,0,L"Segoe UI");
    a.mono=CreateFontW(-px(12),0,0,0,FW_BOLD,0,0,0,DEFAULT_CHARSET,0,0,CLEARTYPE_QUALITY,0,L"Consolas");
    for(HWND h:{
        a.lang,a.preset,a.show,a.spoof,a.restore,a.apply,a.restoreColor,a.status,a.test
    })if(h)SendMessageW(h,WM_SETFONT,(WPARAM)a.body,TRUE);
}
void txt(HWND h,const std::wstring&s){
    SetWindowTextW(h,s.c_str());
}
void labels(){
    txt(a.lang,L"English / Vietnamese");
    txt(a.show,S(L"VIEW GPU",L"XEM GPU"));
    txt(a.spoof,S(L"CHOOSE GPU NAME",L"CHỌN TÊN GPU"));
    txt(a.restore,S(L"RESTORE GPU NAME",L"KHÔI PHỤC TÊN GPU"));
    txt(a.apply,S(L"APPLY COLOR",L"ÁP DỤNG MÀU"));
    txt(a.restoreColor,S(L"RESTORE COLOR",L"KHÔI PHỤC MÀU"));
    txt(a.status,S(L"VIEW ACE STATUS",L"XEM TRẠNG THÁI ACE"));
    txt(a.test,S(L"RUN ACE SELF-TEST",L"CHẠY KIỂM TRA ACE"));
    int n=(int)SendMessageW(a.preset,CB_GETCURSEL,0,0);
    SendMessageW(a.preset,CB_RESETCONTENT,0,0);
    const wchar_t*en[]={
        L"C1 · Standard sRGB",L"C2 · Esport Cool",L"C3 · Shadow Lift",L"C4 · Streamer Warm",L"C5 · Max Contrast",L"L1 · MingJi",L"L2 · Cinema",L"L3 · Soft",L"L4 · AntiGlare",L"L5 · Bright",L"L6 · Vivid",L"L7 · Daylight"
    };
    const wchar_t*vi[]={
        L"C1 · sRGB tiêu chuẩn",L"C2 · Esport mát",L"C3 · Nâng vùng tối",L"C4 · Streamer ấm",L"C5 · Tương phản tối đa",L"L1 · MingJi",L"L2 · Điện ảnh",L"L3 · Dịu",L"L4 · Chống chói",L"L5 · Sáng",L"L6 · Rực rỡ",L"L7 · Ánh sáng ngày"
    };
    for(int i=0;i<12;i++)SendMessageW(a.preset,CB_ADDSTRING,0,(LPARAM)(a.vi?vi[i]:en[i]));
    SendMessageW(a.preset,CB_SETCURSEL,n<0?0:n,0);
}
void move(HWND h,int x,int y,int w,int hgt){
    MoveWindow(h,px(x),px(y),px(w),px(hgt),TRUE);
}
void layout(){
    RECT r{
    };
    GetClientRect(a.w,&r);
    int W=MulDiv(r.right,96,a.dpi),p=28,g=16,c=(W-2*p-2*g)/3,t=142;
    move(a.lang,W-236,26,208,38);
    move(a.show,p+20,t+142,c-40,46);
    move(a.spoof,p+20,t+198,c-40,46);
    move(a.restore,p+20,t+254,c-40,46);
    move(a.preset,p+c+g+20,t+140,c-40,220);
    move(a.apply,p+c+g+20,t+198,c-40,46);
    move(a.restoreColor,p+c+g+20,t+254,c-40,46);
    move(a.status,p+2*(c+g)+20,t+142,c-40,46);
    move(a.test,p+2*(c+g)+20,t+198,c-40,46);
}
void run(const std::wstring& act){
    if(a.child){
        Msg(S(L"An operation is already open.",L"Một tác vụ đang mở."),MB_ICONINFORMATION);
        return;
    }
    if(act==L"SpoofGpu"&&Msg(S(L"The GPU-name chooser opens in a console. Continue?",L"Trình chọn tên GPU sẽ mở trong cửa sổ dòng lệnh. Tiếp tục?"),MB_YESNO|MB_ICONWARNING)!=IDYES)return;
    std::wstring script=Dir()+L"\\backend\\GpuTool.i18n.ps1";
    if(GetFileAttributesW(script.c_str())==INVALID_FILE_ATTRIBUTES){
        Msg(S(L"The backend folder was not found.",L"Không tìm thấy thư mục backend."),MB_ICONERROR);
        return;
    }
    std::wstring args=L"-NoLogo -NoProfile -ExecutionPolicy Bypass -File \""+script+L"\" -Language "+(a.vi?L"vi":L"en")+L" -Action "+act;
    if(act==L"ApplyIcc"){
        int n=(int)SendMessageW(a.preset,CB_GETCURSEL,0,0);
        std::wstring k[]={
            L"C1",L"C2",L"C3",L"C4",L"C5",L"L1",L"L2",L"L3",L"L4",L"L5",L"L6",L"L7"
        };
        args+=L" -PresetKey "+k[(n>=0&&n<12)?n:0];
    }
    SHELLEXECUTEINFOW x{
        sizeof(x)
    };
    x.fMask=SEE_MASK_NOCLOSEPROCESS;
    x.hwnd=a.w;
    x.lpVerb=(act==L"ShowGpu"||act==L"AceStatus")?L"open":L"runas";
    auto p=Ps();
    x.lpFile=p.c_str();
    x.lpParameters=args.c_str();
    x.nShow=SW_SHOWNORMAL;
    if(!ShellExecuteExW(&x)){
        if(GetLastError()!=ERROR_CANCELLED)Msg(S(L"Could not start PowerShell.",L"Không thể khởi chạy PowerShell."),MB_ICONERROR);
        return;
    }
    a.child=x.hProcess;
    SetTimer(a.w,POLL,300,nullptr);
    InvalidateRect(a.w,nullptr,TRUE);
}
void paint(HDC d){
    RECT r{
    };
    GetClientRect(a.w,&r);
    HBRUSH b=CreateSolidBrush(bg);
    FillRect(d,&r,b);
    DeleteObject(b);
    SetBkMode(d,TRANSPARENT);
    auto draw=[&](int x,int y,int w,const std::wstring&s,HFONT f,COLORREF c){
        SetTextColor(d,c);
        SelectObject(d,f);
        RECT q{
            px(x),px(y),px(x+w),px(y+45)
        };
        DrawTextW(d,s.c_str(),-1,&q,DT_WORDBREAK|DT_END_ELLIPSIS);
    };
    draw(28,27,500,L"DELTA OPS",a.h1,text);
    draw(30,67,600,S(L"GPU utility control center",L"Trung tâm điều khiển tiện ích GPU"),a.body,muted);
    draw(30,103,800,a.child?S(L"OPERATION IN PROGRESS — CHECK THE CONSOLE",L"TÁC VỤ ĐANG CHẠY — KIỂM TRA CỬA SỔ DÒNG LỆNH"):S(L"READY — ADMINISTRATOR PERMISSION IS REQUESTED ONLY FOR CHANGES",L"SẴN SÀNG — CHỈ YÊU CẦU QUYỀN QUẢN TRỊ KHI THAY ĐỔI"),a.mono,a.child?amber:lime);
    int W=MulDiv(r.right,96,a.dpi),p=28,g=16,c=(W-2*p-2*g)/3,t=142;
    auto card=[&](int x,const wchar_t*tag,const std::wstring&h,const std::wstring&sub){
        RECT q{
            px(x),px(t),px(x+c),px(t+390)
        };
        HBRUSH z=CreateSolidBrush(cardColor);
        FillRect(d,&q,z);
        DeleteObject(z);
        HBRUSH o=CreateSolidBrush(border);
        FrameRect(d,&q,o);
        DeleteObject(o);
        draw(x+20,t+17,c-35,tag,a.mono,lime);
        draw(x+20,t+44,c-35,h,a.h2,text);
        draw(x+20,t+78,c-35,sub,a.body,muted);
    };
    card(p,L"01 / GPU",S(L"Driver identity",L"Nhận diện driver"),S(L"Inspect, choose, or restore the display name.",L"Kiểm tra, chọn hoặc khôi phục tên hiển thị."));
    card(p+c+g,L"02 / COLOR",S(L"Display profile",L"Hồ sơ hiển thị"),S(L"Select one of twelve color presets.",L"Chọn một trong mười hai mẫu màu."));
    card(p+2*(c+g),L"03 / ACE",S(L"ACE controls",L"Điều chỉnh ACE"),S(L"View status or run the process self-test.",L"Xem trạng thái hoặc chạy tự kiểm tra tiến trình."));
    draw(30,(MulDiv(r.bottom,96,a.dpi))-42,W-60,S(L"Changes open PowerShell and may request Administrator permission.",L"Thay đổi sẽ mở PowerShell và có thể yêu cầu quyền Quản trị viên."),a.body,muted);
}
LRESULT CALLBACK Wnd(HWND h,UINT m,WPARAM w,LPARAM l){
    if(m==WM_CREATE){
        a.w=h;
        a.dpi=GetDpiForWindow(h);
        font();
        DWORD s=WS_CHILD|WS_VISIBLE|WS_TABSTOP;
        a.lang=CreateWindowW(L"BUTTON",L"",s|BS_OWNERDRAW,0,0,0,0,h,(HMENU)LANG,0,0);
        a.preset=CreateWindowW(L"COMBOBOX",L"",s|CBS_DROPDOWNLIST|WS_VSCROLL,0,0,0,0,h,(HMENU)PRESET,0,0);
        HWND* hs[]={
            &a.show,&a.spoof,&a.restore,&a.apply,&a.restoreColor,&a.status,&a.test
        };
        int ids[]={
            SHOW,SPOOF,RESTORE,APPLY,RESTORE_COLOR,ACE_STATUS,ACE_TEST
        };
        for(int i=0;i<7;i++)*hs[i]=CreateWindowW(L"BUTTON",L"",s|BS_OWNERDRAW,0,0,0,0,h,reinterpret_cast<HMENU>(static_cast<INT_PTR>(ids[i])),0,0);
        font();
        labels();
        return 0;
    }
    if(m==WM_SIZE){
        layout();
        return 0;
    }
    if(m==WM_DPICHANGED){
        a.dpi=HIWORD(w);
        SetWindowPos(h,0,((RECT*)l)->left,((RECT*)l)->top,((RECT*)l)->right-((RECT*)l)->left,((RECT*)l)->bottom-((RECT*)l)->top,SWP_NOZORDER|SWP_NOACTIVATE);
        font();
        layout();
        InvalidateRect(h,0,TRUE);
        return 0;
    }
    if(m==WM_GETMINMAXINFO){
        ((MINMAXINFO*)l)->ptMinTrackSize={
            px(980),px(670)
        };
        return 0;
    }
    if(m==WM_DRAWITEM){
        auto q=(DRAWITEMSTRUCT*)l;
        if(q->CtlType==ODT_BUTTON){
            bool focus=(q->itemState&ODS_FOCUS)!=0,down=(q->itemState&ODS_SELECTED)!=0;
            HBRUSH z=CreateSolidBrush(down?border:control);
            FillRect(q->hDC,&q->rcItem,z);
            DeleteObject(z);
            HBRUSH o=CreateSolidBrush(focus?lime:border);
            FrameRect(q->hDC,&q->rcItem,o);
            DeleteObject(o);
            wchar_t s[128]{
            };
            GetWindowTextW(q->hwndItem,s,128);
            SetBkMode(q->hDC,TRANSPARENT);
            SetTextColor(q->hDC,text);
            SelectObject(q->hDC,a.body);
            DrawTextW(q->hDC,s,-1,&q->rcItem,DT_CENTER|DT_VCENTER|DT_SINGLELINE);
            return TRUE;
        }
    }
    if(m==WM_COMMAND&&HIWORD(w)==BN_CLICKED){
        switch(LOWORD(w)){
            case LANG:a.vi=!a.vi;
            labels();
            InvalidateRect(h,0,TRUE);
            break;
            case SHOW:run(L"ShowGpu");
            break;
            case SPOOF:run(L"SpoofGpu");
            break;
            case RESTORE:run(L"RestoreGpu");
            break;
            case APPLY:run(L"ApplyIcc");
            break;
            case RESTORE_COLOR:run(L"RestoreIcc");
            break;
            case ACE_STATUS:run(L"AceStatus");
            break;
            case ACE_TEST:run(L"AceTest");
            break;
        }
        return 0;
    }
    if(m==WM_TIMER&&w==POLL&&a.child&&WaitForSingleObject(a.child,0)==WAIT_OBJECT_0){
        DWORD c=1;
        GetExitCodeProcess(a.child,&c);
        CloseHandle(a.child);
        a.child=0;
        KillTimer(h,POLL);
        Msg(c?S(L"The operation window closed with an error. Review its messages before trying again.",L"Cửa sổ tác vụ đã đóng với lỗi. Hãy xem thông báo trước khi thử lại."):S(L"The operation window has closed. Its messages describe the result.",L"Cửa sổ tác vụ đã đóng. Kết quả được ghi trong thông báo của tác vụ."),c?MB_ICONERROR:MB_ICONINFORMATION);
        InvalidateRect(h,0,TRUE);
        return 0;
    }
    if(m==WM_PAINT){
        PAINTSTRUCT p;
        HDC d=BeginPaint(h,&p);
        paint(d);
        EndPaint(h,&p);
        return 0;
    }
    if(m==WM_CLOSE&&a.child){
        if(Msg(S(L"An operation window is still open. Close only this dashboard?",L"Cửa sổ tác vụ vẫn đang mở. Chỉ đóng bảng điều khiển này?"),MB_YESNO|MB_ICONQUESTION)!=IDYES)return 0;
    }
    if(m==WM_DESTROY){
        for(HFONT f:{
            a.h1,a.h2,a.body,a.mono
        })if(f)DeleteObject(f);
        if(a.child)CloseHandle(a.child);
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcW(h,m,w,l);
}
int WINAPI wWinMain(HINSTANCE i,HINSTANCE,PWSTR,int){
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    a.dpi=GetDpiForSystem();
    InitCommonControls();
    WNDCLASSW c{
    };
    c.hInstance=i;
    c.lpszClassName=L"DeltaOps";
    c.lpfnWndProc=Wnd;
    c.hCursor=LoadCursor(0,IDC_ARROW);
    RegisterClassW(&c);
    HWND h=CreateWindowW(c.lpszClassName,L"Delta Ops",WS_OVERLAPPEDWINDOW|WS_VISIBLE,60,60,px(1100),px(700),0,0,i,0);
    MSG m;
    while(GetMessageW(&m,0,0,0)){
        if(!IsDialogMessageW(h,&m)){
            TranslateMessage(&m);
            DispatchMessageW(&m);
        }
    }
    return 0;
}
