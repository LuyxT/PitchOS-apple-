import { Body, Controller, Delete, Param, Put } from '@nestjs/common';
import { CompatService } from '../compat.service';

@Controller('players')
export class PlayersCompatController {
  constructor(private readonly compatService: CompatService) {}

  @Put(':id')
  updatePlayer(@Param('id') id: string, @Body() _body: Record<string, unknown>) {
    return this.compatService.player(id);
  }

  @Delete(':id')
  deletePlayer(@Param('id') _id: string) {
    return this.compatService.emptyObject();
  }
}
