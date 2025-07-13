import winston from 'winston';

export class Logger {
  private logger: winston.Logger;

  constructor(context: string = 'App') {
    const transports: winston.transport[] = [
      new winston.transports.Console({
        format: winston.format.combine(
          winston.format.colorize(),
          winston.format.printf(({ level, message, timestamp }) => {
            return `${timestamp} [${context}] ${level}: ${message}`;
          })
        ),
      }),
    ];

    // 在非测试环境下添加文件日志
    if (process.env.NODE_ENV !== 'test') {
      transports.push(
        new winston.transports.File({
          filename: '/app/logs/hot-reload.log',
          maxsize: 10 * 1024 * 1024, // 10MB
          maxFiles: 5,
        })
      );
    }

    this.logger = winston.createLogger({
      level: process.env.LOG_LEVEL || 'info',
      format: winston.format.combine(
        winston.format.timestamp({
          format: 'YYYY-MM-DD HH:mm:ss',
        }),
        winston.format.errors({ stack: true }),
        winston.format.printf(({ level, message, timestamp, stack }) => {
          let log = `${timestamp} [${context}] ${level.toUpperCase()}: ${message}`;
          if (stack) {
            log += `\n${stack}`;
          }
          return log;
        })
      ),
      transports,
    });
  }

  public info(message: string, ...meta: unknown[]): void {
    this.logger.info(message, ...meta);
  }

  public warn(message: string, ...meta: unknown[]): void {
    this.logger.warn(message, ...meta);
  }

  public error(message: string, ...meta: unknown[]): void {
    this.logger.error(message, ...meta);
  }

  public debug(message: string, ...meta: unknown[]): void {
    this.logger.debug(message, ...meta);
  }
}
