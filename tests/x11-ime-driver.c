#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef Bool (*fake_key_event_fn)(Display *, unsigned int, Bool, unsigned long);
typedef Bool (*fake_button_event_fn)(Display *, unsigned int, Bool, unsigned long);
typedef Bool (*fake_motion_event_fn)(Display *, int, int, int, unsigned long);

static Window find_window(Display *display, Window parent, const char *needle)
{
    Window root, parent_return, *children = NULL;
    unsigned int count = 0, i;
    char *name = NULL;
    Window result = None;

    if (XFetchName(display, parent, &name) && name)
    {
        if (strstr(name, needle)) result = parent;
        XFree(name);
        if (result != None) return result;
    }
    if (!XQueryTree(display, parent, &root, &parent_return, &children, &count))
        return None;
    for (i = 0; i < count && result == None; ++i)
        result = find_window(display, children[i], needle);
    if (children) XFree(children);
    return result;
}

static int send_key(Display *display, fake_key_event_fn fake_key, KeySym symbol)
{
    KeyCode code = XKeysymToKeycode(display, symbol);
    if (!code) return 0;
    fake_key(display, code, True, CurrentTime);
    usleep(35000);
    fake_key(display, code, False, CurrentTime);
    usleep(100000);
    return 1;
}

int main(int argc, char **argv)
{
    Display *display;
    Window root, window, child;
    int root_x, root_y, i;
    void *xtst;
    fake_key_event_fn fake_key;
    fake_button_event_fn fake_button;
    fake_motion_event_fn fake_motion;

    if (argc < 2 || argc > 3)
    {
        fprintf(stderr, "usage: %s TITLE_SUBSTRING [ASCII_TEXT]\n", argv[0]);
        return 64;
    }
    display = XOpenDisplay(NULL);
    if (!display) return 65;
    root = DefaultRootWindow(display);
    window = find_window(display, root, argv[1]);
    if (window == None)
    {
        fprintf(stderr, "window not found: %s\n", argv[1]);
        XCloseDisplay(display);
        return 66;
    }

    xtst = dlopen("libXtst.so.6", RTLD_NOW | RTLD_LOCAL);
    if (!xtst) return 67;
    fake_key = (fake_key_event_fn)dlsym(xtst, "XTestFakeKeyEvent");
    fake_button = (fake_button_event_fn)dlsym(xtst, "XTestFakeButtonEvent");
    fake_motion = (fake_motion_event_fn)dlsym(xtst, "XTestFakeMotionEvent");
    if (!fake_key || !fake_button || !fake_motion) return 68;

    XRaiseWindow(display, window);
    XSetInputFocus(display, window, RevertToParent, CurrentTime);
    XTranslateCoordinates(display, window, root, 100, 35,
                          &root_x, &root_y, &child);
    fake_motion(display, DefaultScreen(display), root_x, root_y, CurrentTime);
    fake_button(display, 1, True, CurrentTime);
    fake_button(display, 1, False, CurrentTime);
    XFlush(display);
    usleep(500000);

    if (argc == 3)
    {
        for (i = 0; argv[2][i]; ++i)
        {
            char key_name[2] = {argv[2][i], 0};
            if (!send_key(display, fake_key, XStringToKeysym(key_name))) return 69;
        }
        send_key(display, fake_key, XK_space);
        XFlush(display);
    }

    printf("window=0x%lx root=%d,%d\n", window, root_x, root_y);
    fflush(stdout);
    XFlush(display);
    _exit(0);
}
