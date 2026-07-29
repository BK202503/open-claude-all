import {
  ArgumentsHost,
  Catch,
  Controller,
  ExceptionFilter,
  Get,
  HttpException,
  Module,
  UseFilters,
} from "@nestjs/common";
import { APP_FILTER } from "@nestjs/core";

@Catch()
export class GenericFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const res = host.switchToHttp().getResponse();
    res.status(500).json({ error: "generic", detail: String(exception) });
  }
}

@Catch(HttpException)
export class SpecificFilter implements ExceptionFilter {
  catch(exception: HttpException, host: ArgumentsHost) {
    const res = host.switchToHttp().getResponse();
    res.status(exception.getStatus()).json({ error: "http", message: exception.message });
  }
}

@UseFilters(SpecificFilter)
@Controller("things")
export class ThingsController {
  @Get()
  list() {
    throw new HttpException("nope", 404);
  }
}

@Module({
  controllers: [ThingsController],
  providers: [{ provide: APP_FILTER, useClass: GenericFilter }],
})
export class ThingsModule {}
