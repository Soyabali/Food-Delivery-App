from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException


class ApiError(Exception):
    """Raise from services/routes; rendered as {"message": ...}."""

    def __init__(self, status_code: int, message: str):
        self.status_code = status_code
        self.message = message


def _field(loc: tuple) -> str:
    parts = [str(p) for p in loc if p not in ("body", "query", "path")]
    return ".".join(parts) or "request"


def register_error_handlers(app: FastAPI) -> None:
    """The mobile app reads errors as {"message": "..."} (see ApiException)."""

    @app.exception_handler(ApiError)
    async def _api_error(_: Request, exc: ApiError):
        return JSONResponse(status_code=exc.status_code, content={"message": exc.message})

    @app.exception_handler(StarletteHTTPException)
    async def _http_error(_: Request, exc: StarletteHTTPException):
        return JSONResponse(
            status_code=exc.status_code,
            content={"message": str(exc.detail)},
            headers=getattr(exc, "headers", None),
        )

    @app.exception_handler(RequestValidationError)
    async def _validation_error(_: Request, exc: RequestValidationError):
        errors = [{"field": _field(e["loc"]), "message": e["msg"]} for e in exc.errors()]
        first = errors[0] if errors else {"field": "request", "message": "Invalid request"}
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            content={"message": f"{first['field']}: {first['message']}", "errors": errors},
        )
