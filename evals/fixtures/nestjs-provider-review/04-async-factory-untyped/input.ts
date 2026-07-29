import { Inject, Injectable, Module } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";

export const DB_CONNECTION = "DB_CONNECTION";

@Injectable()
export class LoggerService {
  log(msg: string) {
    console.log(msg);
  }
}

@Module({
  providers: [
    LoggerService,
    {
      provide: DB_CONNECTION,
      useFactory: async (config: ConfigService, logger: LoggerService) => {
        logger.log("connecting");
        const url = config.get<string>("DB_URL");
        return { url, query: async (_sql: string) => [] };
      },
      inject: [ConfigService],
    },
  ],
  exports: [DB_CONNECTION],
})
export class DatabaseModule {}

@Injectable()
export class UsersRepository {
  constructor(@Inject(DB_CONNECTION) private readonly db: any) {}
  find(id: string) {
    return this.db.query(`select * from users where id = '${id}'`);
  }
}
