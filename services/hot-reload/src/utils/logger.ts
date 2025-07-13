import winston from 'winston';

export class Logger {
  private logger: winston.Logger;
  
  constructor(context: string = 'App') {
    this.logger = winston.createLogger({
      level: process.env.LOG_LEVEL || 'info',
      format: winston.format.combine(
        winston.format.timestamp({
          format: 'YYYY-MM-DD HH:mm:ss'
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
      transports: [
        new winston.transports.Console({
          format: winston.format.combine(
            winston.format.colorize(),
            winston.format.printf(({ level, message, timestamp }) => {
              return `${timestamp} [${context}] ${level}: ${message}`;
            })
          )
        }),
        new winston.transports.File({
          filename: '/app/logs/hot-reload.log',
          maxsize: 10 * 1024 * 1024, // 10MB
          maxFiles: 5
        })
      ]
    });
  }
  
  public info(message: string, ...meta: any[]): void {
    this.logger.info(message, ...meta);
  }
  
  public warn(message: string, ...meta: any[]): void {
    this.logger.warn(message, ...meta);
  }
  
  public error(message: string, ...meta: any[]): void {
    this.logger.error(message, ...meta);
  }
  
  public debug(message: string, ...meta: any[]): void {
    this.logger.debug(message, ...meta);
  }
}