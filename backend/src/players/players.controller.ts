import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { CreatePlayerDto } from './dto/create-player.dto';
import { ListPlayersDto } from './dto/list-players.dto';
import { PlayersService } from './players.service';

@Controller('players')
export class PlayersController {
  constructor(private readonly playersService: PlayersService) {}

  @Post()
  async createPlayer(@Body() dto: CreatePlayerDto) {
    return this.playersService.createPlayer(dto);
  }

  @Get()
  async listPlayers(@Query() query: ListPlayersDto) {
    return this.playersService.listPlayers(query.teamId);
  }
}
