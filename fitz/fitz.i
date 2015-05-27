%module fitz

/* 
#define MEMDEBUG
*/

%{
#define SWIG_FILE_WITH_INIT
#include <fitz.h>
%}

/* global context */
%init %{
    gctx = fz_new_context(NULL, NULL, FZ_STORE_UNLIMITED);
    fz_register_document_handlers(gctx);
%}
%header %{
    fz_context *gctx;
%}
    

/* fz_document */
%rename(Document) fz_document_s;
struct fz_document_s {
    %extend {
        %exception fz_document_s {
            $action
            if(!result) {
                PyErr_SetString(PyExc_Exception, "cannot create Document");
                return NULL;
            }
        }
        %pythonprepend fz_document_s(const char *) %{
            if type(filename) == str:
                pass
            elif type(filename) == unicode:
                filename = filename.encode('utf8')
            else:
                raise TypeError("filename must be a string")
        %}
        %pythonappend fz_document_s(const char *) %{
            if this:
                self._outline = self._loadOutline() 
        %}
        fz_document_s(const char *filename) {
            struct fz_document_s *doc;
            fz_try(gctx)
                doc = fz_open_document(gctx, filename);
            fz_catch(gctx)
                doc = NULL;
            return doc;
        }

        %pythonprepend ~fz_document_s() %{
            if hasattr(self, '_outline') and self._outline:
                self._dropOutline(self._outline)
        %}
        ~fz_document_s() {
#ifdef MEMDEBUG
            fprintf(stderr, "free doc\n");
#endif
            fz_drop_document(gctx, $self);
        }

        %exception loadPage {
            $action
            if(!result) {
                PyErr_SetString(PyExc_Exception, "cannot loadPage");
                return NULL;
            }
        }
        %pythonappend loadPage(int) %{
            if val:
                val.thisown = True
        %}
        struct fz_page_s *loadPage(int number) {
            struct fz_page_s *page;
            fz_try(gctx)
                page = fz_load_page(gctx, $self, number);
            fz_catch(gctx)
                page = NULL;
            return page;
        }

        struct fz_outline_s *_loadOutline() {
            return fz_load_outline(gctx, $self);
        }
        void _dropOutline(struct fz_outline_s *ol) {
#ifdef MEMDEBUG
            fprintf(stderr, "free outline\n");
#endif
            fz_drop_outline(gctx, ol);
        }
        int _getPageCount() {
            return fz_count_pages(gctx, $self);
        }

        %pythoncode %{
            pageCount = property(_getPageCount)
            outline = property(lambda self: self._outline)
        %}
    }
};


/* fz_page */
%nodefaultctor;
%rename(Page) fz_page_s;
struct fz_page_s {
    %extend {
        ~fz_page_s() {
#ifdef MEMDEBUG
            fprintf(stderr, "free page\n");
#endif
            fz_drop_page(gctx, $self);
        }

        %pythonappend bound() %{
            if val:
                val.thisown = True
        %}
        struct fz_rect_s *bound() {
            fz_rect *rect = (fz_rect *)malloc(sizeof(fz_rect));
            fz_bound_page(gctx, $self, rect);
            return rect;
        }

        %exception run {
            $action
            if(result) {
                PyErr_SetString(PyExc_Exception, "cannot run page");
                return NULL;
            }
        }
        int run(struct fz_device_s *dev, const struct fz_matrix_s *m) {
            fz_try(gctx) {
                fz_run_page(gctx, $self, dev, m, NULL);
            }
            fz_catch(gctx) {
                return 1;
            }
            return 0;
        }
        %pythonappend loadLinks() %{
            if val:
                val.thisown = True
        %}
        struct fz_link_s *loadLinks() {
            return fz_load_links(gctx, $self);
        }
    }
};
%clearnodefaultctor;


/* fz_rect */
%rename(_fz_transform_rect) fz_transform_rect;
struct fz_rect_s *fz_transform_rect(struct fz_rect_s *restrict rect, const struct fz_matrix_s *restrict transform);
%rename(Rect) fz_rect_s;
struct fz_rect_s
{
    float x0, y0;
    float x1, y1;
    fz_rect_s();
    %extend {
        fz_rect_s(const struct fz_rect_s *s) {
            fz_rect *r = (fz_rect *)malloc(sizeof(fz_rect));
            *r = *s;
            return r;
        }
#ifdef MEMDEBUG
        ~fz_rect_s() {
            fprintf(stderr, "free rect\n");
            free($self);
        }
#endif
        %pythonappend round() %{
            val.thisown = True
        %}
        struct fz_irect_s *round() {
            fz_irect *irect = (fz_irect *)malloc(sizeof(fz_irect));
            fz_round_rect(irect, $self);
            return irect;
        }
        %pythoncode %{
            def transform(self, m):
                _fitz._fz_transform_rect(self, m)
                return self
            width = property(lambda self: self.x1-self.x0)
            height = property(lambda self: self.y1-self.y0)
        %}
    }
};


/* fz_irect */
%rename(IRect) fz_irect_s;
struct fz_irect_s
{
    int x0, y0;
    int x1, y1;
    fz_irect_s();
    %extend {
#ifdef MEMDEBUG
        ~fz_irect_s() {
            fprintf(stderr, "free irect\n");
            free($self);
        }
#endif
        fz_irect_s(const struct fz_irect_s *s) {
            fz_irect *r = (fz_irect *)malloc(sizeof(fz_irect));
            *r = *s;
            return r;
        }
        %pythoncode %{
            width = property(lambda self: self.x1-self.x0)
            height = property(lambda self: self.y1-self.y0)
        %}
    }
};


/* fz_pixmap */
%rename(Pixmap) fz_pixmap_s;
struct fz_pixmap_s
{
    int x, y, w, h, n;
    int interpolate;
    int xres, yres;
    %extend {
        %exception fz_pixmap_s {
            $action
            if(!result) {
                PyErr_SetString(PyExc_Exception, "cannot create Pixmap");
                return NULL;
            }
        }
        fz_pixmap_s(struct fz_colorspace_s *cs, const struct fz_irect_s *bbox) {
            struct fz_pixmap_s *pm;
            fz_try(gctx)
                pm = fz_new_pixmap_with_bbox(gctx, cs, bbox);
            fz_catch(gctx)
                pm = NULL;
            return pm;
        }

        ~fz_pixmap_s() {
#ifdef MEMDEBUG
            fprintf(stderr, "free pixmap\n");
#endif
            fz_drop_pixmap(gctx, $self);
        }
        void clearWith(int value) {
            fz_clear_pixmap_with_value(gctx, $self, value);
        }

        %exception writePNG {
            $action
            if(result) {
                PyErr_SetString(PyExc_Exception, "cannot writePNG");
                return NULL;
            }
        }
        int writePNG(char *filename, int savealpha=0) {
            fz_try(gctx) {
                fz_write_png(gctx, $self, filename, savealpha);
            }
            fz_catch(gctx) 
                return 1;
            return 0;
        }
        void invertIRect(const struct fz_irect_s *irect) {
            fz_invert_pixmap_rect(gctx, $self, irect);
        }
        PyObject *_getSamples() {
            return PyByteArray_FromStringAndSize((const char *)$self->samples, ($self->w)*($self->h)*($self->n));
        }
        %pythoncode %{
            samples = property(lambda self: self._getSamples())
        %}
    }
};


/* fz_colorspace */
#define CS_RGB 1
%inline %{
    #define CS_RGB 1
%}
%rename(Colorspace) fz_colorspace_s;
struct fz_colorspace_s
{
    %extend {
        fz_colorspace_s(int type) {
            switch(type) {
                case CS_RGB:
                default:
                    return fz_device_rgb(gctx);
                    break;
            }
        }
        ~fz_colorspace_s() {
#ifdef MEMDEBUG
            fprintf(stderr, "free colorspace\n");
#endif
            fz_drop_colorspace(gctx, $self);
        }
    } 
};


/* fz_device */
%rename(Device) fz_device_s;
struct fz_device_s
{
    %extend {
        %exception fz_device_s {
            $action
            if(!result) {
                PyErr_SetString(PyExc_Exception, "cannot create Device");
                return NULL;
            }
        }
        fz_device_s(struct fz_pixmap_s *pm) {
            struct fz_device_s *dv;
            fz_try(gctx)
                dv = fz_new_draw_device(gctx, pm);
            fz_catch(gctx)
                dv = NULL;
            return dv;
        }
        fz_device_s(struct fz_display_list_s *dl) {
            struct fz_device_s *dv;
            fz_try(gctx)
                dv = fz_new_list_device(gctx, dl);
            fz_catch(gctx)
                dv = NULL;
            return dv;
        }
        fz_device_s(struct fz_text_sheet_s *ts, struct fz_text_page_s *tp) {
            struct fz_device_s *dv;
            fz_try(gctx)
                dv = fz_new_text_device(gctx, ts, tp);
            fz_catch(gctx)
                dv = NULL;
            return dv;
        }
        ~fz_device_s() {
#ifdef MEMDEBUG
            fprintf(stderr, "free device\n");
#endif
            fz_drop_device(gctx, $self);
        }
    }
};


/* fz_matrix */
%rename(_fz_pre_scale) fz_pre_scale;
%rename(_fz_pre_shear) fz_pre_shear;
%rename(_fz_pre_rotate) fz_pre_rotate;
struct fz_matrix_s *fz_pre_scale(struct fz_matrix_s *m, float sx, float sy);
struct fz_matrix_s *fz_pre_shear(struct fz_matrix_s *m, float sx, float sy);
struct fz_matrix_s *fz_pre_rotate(struct fz_matrix_s *m, float degree);
%rename(Matrix) fz_matrix_s;
struct fz_matrix_s
{
    float a, b, c, d, e, f;
    fz_matrix_s();
    %extend {
#ifdef MEMDEBUG
        ~fz_matrix_s() {
            fprintf(stderr, "free matrix\n");
            free($self);
        }
#endif
        /* copy constructor */
        fz_matrix_s(const struct fz_matrix_s* n) {
            fz_matrix *m = (fz_matrix *)malloc(sizeof(fz_matrix));
            return fz_copy_matrix(m, n);
        }
        /* create a scale/shear matrix, scale matrix by default */
        fz_matrix_s(float sx, float sy, int shear=0) {
            if(shear) {
                fz_matrix *m = (fz_matrix *)malloc(sizeof(fz_matrix));
                return fz_shear(m, sx, sy);
            }
            else {
                fz_matrix *m = (fz_matrix *)malloc(sizeof(fz_matrix));
                return fz_scale(m, sx, sy);
            }
        }
        /* create a rotate matrix */
        fz_matrix_s(float degree) {
            fz_matrix *m = (fz_matrix *)malloc(sizeof(fz_matrix));
            return fz_rotate(m, degree);
        }
        %pythoncode %{
            def preScale(self, sx, sy):
                _fitz._fz_pre_scale(self, sx, sy)
                return self
            def preShear(self, sx, sy):
                _fitz._fz_pre_shear(self, sx, sy)
                return self
            def preRotate(self, degree):
                _fitz._fz_pre_rotate(self, degree)
                return self
        %}
    }
};
%rename(Identity) fz_identity;
%inline %{
    extern const struct fz_matrix_s fz_identity;
%}


/* fz_outline */
%rename(Outline) fz_outline_s;
%nodefaultctor;
struct fz_outline_s {
    %immutable;
    char *title;
    struct fz_link_dest_s dest;
    struct fz_outline_s *next;
    struct fz_outline_s *down;
    int is_open;
/* 
    fz_outline doesn't keep a ref number in mupdf's code,
    which means that if the root outline node is dropped,
    all the outline nodes will also be destroyed.

    As a result, if the root Outline python object drops ref,
    then other Outline will point to already freed area. E.g.:
    >>> import fitz
    >>> doc=fitz.Document('3.pdf')
    >>> ol=doc.loadOutline()
    >>> oln=ol.next
    >>> oln.dest.page
    5
    >>> #drops root outline
    ...
    >>> ol=4
    free outline
    >>> oln.dest.page
    0

    I do not like to change struct of fz_document, so I decide 
    to delegate the outline destructin work to fz_document. That is,
    when the Document is created, its outline is loaded in advance.
    The outline will only be freed when the doc is destroyed, which means
    in the python code, we must keep ref to doc if we still want to use outline
    This is a nasty way but it requires little change to the mupdf code.
    */
/*
    %extend {
        ~fz_outline_s() {
#ifdef MEMDEBUG
            fprintf(stderr, "free outline\n");
#endif
            fz_drop_outline(gctx, $self);
        }
    }
*/
};
%clearnodefaultctor;


/*fz_link_kind */
%rename("%(strip:[FZ_])s") "";
typedef enum fz_link_kind_e
{
    FZ_LINK_NONE = 0,
    FZ_LINK_GOTO,
    FZ_LINK_URI,
    FZ_LINK_LAUNCH,
    FZ_LINK_NAMED,
    FZ_LINK_GOTOR
} fz_link_kind;


/* fz_link_dest */
%rename(linkDest) fz_link_dest_s;
%nodefaultctor;
struct fz_link_dest_s {
    %immutable;
    fz_link_kind kind;
    %extend {
        int _getPage() {
            return ($self->kind == FZ_LINK_GOTO || $self->kind == FZ_LINK_GOTOR) ? $self->ld.gotor.page : 0;
        }
        char *_getDest() {
            return ($self->kind == FZ_LINK_GOTO || $self->kind == FZ_LINK_GOTOR) ? $self->ld.gotor.dest : NULL;
        }
        int _getFlags() {
            return ($self->kind == FZ_LINK_GOTO || $self->kind == FZ_LINK_GOTOR) ? $self->ld.gotor.flags : 0;
        }
        struct fz_point_s *_getLt() {
            return ($self->kind == FZ_LINK_GOTO || $self->kind == FZ_LINK_GOTOR) ? &($self->ld.gotor.lt) : NULL;
        }
        struct fz_point_s *_getRb() {
            return ($self->kind == FZ_LINK_GOTO || $self->kind == FZ_LINK_GOTOR) ? &($self->ld.gotor.rb) : NULL;
        }
        char *_getFileSpec() {
            return ($self->kind == FZ_LINK_GOTO || $self->kind == FZ_LINK_GOTOR) ? $self->ld.gotor.file_spec : ($self->kind==FZ_LINK_LAUNCH ? $self->ld.launch.file_spec : NULL);
        }
        int _getNewWindow() {
            return ($self->kind == FZ_LINK_GOTO || $self->kind == FZ_LINK_GOTOR) ? $self->ld.gotor.new_window : ($self->kind==FZ_LINK_LAUNCH ? $self->ld.launch.new_window : 0);
        }
        char *_getUri() {
            return ($self->kind == FZ_LINK_URI) ? $self->ld.uri.uri : NULL;
        }
        int _getIsMap() {
            return ($self->kind == FZ_LINK_URI) ? $self->ld.uri.is_map : 0;
        }
        int _getIsUri() {
            return $self->kind == FZ_LINK_LAUNCH ? $self->ld.launch.is_uri : 0;
        }
        char *_getNamed() {
            return $self->kind == FZ_LINK_NAMED ? $self->ld.named.named : NULL;
        }
        ~fz_link_dest_s() {
#ifdef MEMDEBUG
            fprintf(stderr, "free link_dest\n");
#endif
            fz_drop_link_dest(gctx, $self);
        }
    }
    %pythoncode %{
        page = property(_getPage)
        dest = property(_getDest)
        flags = property(_getFlags)
        lt = property(_getLt)
        rb = property(_getRb)
        fileSpec = property(_getFileSpec)
        newWindow = property(_getNewWindow)
        uri = property(_getUri)
        isMap = property(_getIsMap)
        isUri = property(_getIsUri)
        named = property(_getNamed)
    %}
};
%clearnodefaultctor;

/* fz_point */
%rename(_fz_transform_point) fz_transform_point;
struct fz_point_s *fz_transform_point(struct fz_point_s *restrict point, const struct fz_matrix_s *restrict transform);
%rename(Point) fz_point_s;
struct fz_point_s
{
    float x, y;
    fz_point_s();
    %extend {
#ifdef MEMDEBUG
        ~fz_point_s() {
            fprintf(stderr, "free point\n");
            free($self);
        }
#endif
        fz_point_s(const struct fz_point_s *q) {
            fz_point *p = (fz_point *)malloc(sizeof(fz_point));
            *p = *q;
            return p;
        }
        %pythoncode %{
            def transform(self, m):
                _fitz._fz_transform_point(self, m)
                return self
        %}
    }
};


/* fz_link */
%rename("%(regex:/fz_(.*)/\\U\\1/)s") "";
enum {
    fz_link_flag_l_valid = 1, /* lt.x is valid */
    fz_link_flag_t_valid = 2, /* lt.y is valid */
    fz_link_flag_r_valid = 4, /* rb.x is valid */
    fz_link_flag_b_valid = 8, /* rb.y is valid */
    fz_link_flag_fit_h = 16, /* Fit horizontally */
    fz_link_flag_fit_v = 32, /* Fit vertically */
    fz_link_flag_r_is_zoom = 64 /* rb.x is actually a zoom figure */
};
%rename(Link) fz_link_s;
%nodefaultctor;
struct fz_link_s
{
    %immutable;
    int refs;
    struct fz_rect_s rect;
    struct fz_link_dest_s dest;
    %extend {
        ~fz_link_s() {
#ifdef MEMDEBUG
            fprintf(stderr, "free link\n");
#endif
            fz_drop_link(gctx, $self);
        }
        /* we need to increase the link refs number so that it won't be freed when the head is dropped */
        %pythonappend _getNext() %{
            if val:
                val.thisown = True
        %}
        struct fz_link_s *_getNext() {
            fz_keep_link(gctx, $self->next);
            return $self->next;
        }
        %pythoncode %{
            next = property(_getNext)
        %}
    }
};
%clearnodefaultctor;


/* fz_display_list */
%rename(DisplayList) fz_display_list_s;
struct fz_display_list_s {
    %extend {
        %exception fz_display_list_s {
            $action
            if(!result) {
                PyErr_SetString(PyExc_Exception, "cannot create DisplayList");
                return NULL;
            }
        }
        fz_display_list_s() {
            struct fz_display_list_s *dl;
            fz_try(gctx)
                dl = fz_new_display_list(gctx);
            fz_catch(gctx)
                dl = NULL;
            return dl;
        }

        ~fz_display_list_s() {
#ifdef MEMDEBUG
            fprintf(stderr, "free display list\n");
#endif
            fz_drop_display_list(gctx, $self);
        }
        %exception run {
            $action
            if(result) {
                PyErr_SetString(PyExc_Exception, "cannot run display list");
                return NULL;
            }
        }
        int run(struct fz_device_s *dev, const struct fz_matrix_s *m, const struct fz_rect_s *area) {
            fz_try(gctx) {
                fz_run_display_list(gctx, $self, dev, m, area, NULL);
            }
            fz_catch(gctx)
                return 1;
            return 0;
        }
    }
};


/* fz_text_sheet */
%rename(TextSheet) fz_text_sheet_s;
struct fz_text_sheet_s {
    %extend {
        %exception fz_text_sheet_s {
            $action
            if(!result) {
                PyErr_SetString(PyExc_Exception, "cannot create TextSheet");
                return NULL;
            }
        }
        fz_text_sheet_s() {
            struct fz_text_sheet_s *ts;
            fz_try(gctx)
                ts = fz_new_text_sheet(gctx);
            fz_catch(gctx)
                ts = NULL;
            return ts;
        }

        ~fz_text_sheet_s() {
#ifdef MEMDEBUG
            fprintf(stderr, "free text sheet\n");
#endif
            fz_drop_text_sheet(gctx, $self);
        }
    }
};

/* fz_text_page */
%typemap(out) struct fz_rect_s * {
    PyObject *pyRect;
    struct fz_rect_s *rect;
    $result = PyList_New(0);
    rect = (struct fz_rect_s *)$1;
    while(!fz_is_empty_rect(rect)) {
        pyRect = SWIG_NewPointerObj(memcpy(malloc(sizeof(struct fz_rect_s)), rect, sizeof(struct fz_rect_s)), SWIGTYPE_p_fz_rect_s, SWIG_POINTER_OWN);
        PyList_Append($result, pyRect);
        Py_DECREF(pyRect);
        rect += 1;
    }
    free($1);
}
%rename(TextPage) fz_text_page_s;
struct fz_text_page_s {
    %extend {
        %exception fz_text_page_s {
            $action
            if(!result) {
                PyErr_SetString(PyExc_Exception, "cannot create TextPage");
                return NULL;
            }
        }
        fz_text_page_s() {
            struct fz_text_page_s *tp;
            fz_try(gctx)
                tp = fz_new_text_page(gctx);
            fz_catch(gctx)
                tp = NULL;
            return tp;
        }

        ~fz_text_page_s() {
#ifdef MEMDEBUG
            fprintf(stderr, "free text page\n");
#endif
            fz_drop_text_page(gctx, $self);
        }
        struct fz_rect_s *search(const char *needle, int hit_max=16) {
            fz_rect *result;
            int count;
            if(hit_max < 0) {
                fprintf(stderr, "invalid hit max number %d\n", hit_max);
                return NULL;
            }
            result = (fz_rect *)malloc(sizeof(fz_rect)*(hit_max+1));
            count = fz_search_text_page(gctx, $self, needle, result, hit_max);
            result[count] = fz_empty_rect;
#ifdef MEMDEBUG
            fprintf(stderr, "count is %d, last one is (%g %g), (%g %g)\n", count, result[count].x0, result[count].y0, result[count].x1, result[count].y1);
#endif
            return result;
        }
    }
};


