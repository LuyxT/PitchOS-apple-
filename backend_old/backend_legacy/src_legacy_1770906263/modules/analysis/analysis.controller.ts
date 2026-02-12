import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';
import {
  CreateAnalysisSessionDto,
  CreateClipDto,
  CreateMarkerDto,
  SaveDrawingDto,
  ShareClipDto,
  UpdateClipDto,
  UpdateMarkerDto,
} from './dto/analysis.dto';
import { AnalysisService } from './analysis.service';

@ApiTags('analysis')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('analysis')
export class AnalysisController {
  constructor(private readonly analysisService: AnalysisService) {}

  @Get('sessions')
  async listSessions(@CurrentUser() user: JwtPayload, @Query('teamId') teamId?: string) {
    return this.analysisService.listSessions(user, teamId);
  }

  @Get('sessions/:id')
  async getSession(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.analysisService.getSession(user, id);
  }

  @Post('sessions')
  async createSession(@CurrentUser() user: JwtPayload, @Body() body: CreateAnalysisSessionDto) {
    return this.analysisService.createSession(user, body);
  }

  @Post('sessions/:id/markers')
  async createMarker(
    @CurrentUser() user: JwtPayload,
    @Param('id') sessionId: string,
    @Body() body: CreateMarkerDto,
  ) {
    return this.analysisService.createMarker(user, sessionId, body);
  }

  @Patch('markers/:id')
  async updateMarker(
    @CurrentUser() user: JwtPayload,
    @Param('id') markerId: string,
    @Body() body: UpdateMarkerDto,
  ) {
    return this.analysisService.updateMarker(user, markerId, body);
  }

  @Delete('markers/:id')
  async deleteMarker(@CurrentUser() user: JwtPayload, @Param('id') markerId: string) {
    return this.analysisService.deleteMarker(user, markerId);
  }

  @Post('sessions/:id/clips')
  async createClip(
    @CurrentUser() user: JwtPayload,
    @Param('id') sessionId: string,
    @Body() body: CreateClipDto,
  ) {
    return this.analysisService.createClip(user, sessionId, body);
  }

  @Patch('clips/:id')
  async updateClip(
    @CurrentUser() user: JwtPayload,
    @Param('id') clipId: string,
    @Body() body: UpdateClipDto,
  ) {
    return this.analysisService.updateClip(user, clipId, body);
  }

  @Delete('clips/:id')
  async deleteClip(@CurrentUser() user: JwtPayload, @Param('id') clipId: string) {
    return this.analysisService.deleteClip(user, clipId);
  }

  @Put('sessions/:id/drawings')
  async saveDrawings(
    @CurrentUser() user: JwtPayload,
    @Param('id') sessionId: string,
    @Body() drawings: SaveDrawingDto[],
  ) {
    return this.analysisService.saveDrawings(user, sessionId, drawings);
  }

  @Post('clips/:id/share')
  async shareClip(
    @CurrentUser() user: JwtPayload,
    @Param('id') clipId: string,
    @Body() body: ShareClipDto,
  ) {
    return this.analysisService.shareClip(user, clipId, body);
  }
}
