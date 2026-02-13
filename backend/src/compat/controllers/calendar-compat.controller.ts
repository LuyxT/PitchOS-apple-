import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
} from '@nestjs/common';
import { CompatService } from '../compat.service';

@Controller('calendar')
export class CalendarCompatController {
  constructor(private readonly compatService: CompatService) {}

  @Get('categories')
  categories() {
    return [
      this.compatService.calendarCategoryTraining(),
      this.compatService.calendarCategoryMatch(),
    ];
  }

  @Get('events')
  events() {
    return this.compatService.emptyArray();
  }

  @Post('events')
  createEvent(@Body() _body: Record<string, unknown>) {
    return this.compatService.calendarEvent();
  }

  @Put('events/:id')
  updateEvent(@Param('id') id: string, @Body() _body: Record<string, unknown>) {
    return this.compatService.calendarEvent(id);
  }

  @Delete('events/:id')
  deleteEvent(@Param('id') _id: string) {
    return this.compatService.emptyObject();
  }
}
