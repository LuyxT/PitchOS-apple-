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

@Controller('analysis')
export class AnalysisCompatController {
  constructor(private readonly compatService: CompatService) {}

  @Post('videos/register')
  registerVideo(@Body() _body: Record<string, unknown>) {
    return this.compatService.analysisVideoRegisterResponse();
  }

  @Post('videos/:videoId/complete')
  completeVideo(
    @Param('videoId') videoId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.analysisVideoCompleteResponse(videoId);
  }

  @Get('videos/:videoId/playback')
  playbackUrl(@Param('videoId') _videoId: string) {
    return this.compatService.signedPlaybackResponse();
  }

  @Get('sessions')
  sessions() {
    return this.compatService.emptyArray();
  }

  @Post('sessions')
  createSession(@Body() _body: Record<string, unknown>) {
    return this.compatService.analysisSession();
  }

  @Get('sessions/:id')
  sessionEnvelope(@Param('id') id: string) {
    return this.compatService.analysisSessionEnvelope(id);
  }

  @Put('sessions/:sessionId/drawings')
  saveDrawings(
    @Param('sessionId') _sessionId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.emptyObject();
  }

  @Get('markers')
  markers() {
    return this.compatService.emptyArray();
  }

  @Post('markers')
  createMarker(@Body() body: Record<string, unknown>) {
    const sessionId =
      typeof body.sessionID === 'string' ? body.sessionID : undefined;
    return this.compatService.analysisMarker(undefined, sessionId);
  }

  @Put('markers/:id')
  updateMarker(@Param('id') id: string, @Body() _body: Record<string, unknown>) {
    return this.compatService.analysisMarker(id);
  }

  @Delete('markers/:id')
  deleteMarker(@Param('id') _id: string) {
    return this.compatService.emptyObject();
  }

  @Get('clips')
  clips() {
    return this.compatService.emptyArray();
  }

  @Post('clips')
  createClip(@Body() body: Record<string, unknown>) {
    const sessionId =
      typeof body.sessionID === 'string' ? body.sessionID : undefined;
    return this.compatService.analysisClip(undefined, sessionId);
  }

  @Put('clips/:id')
  updateClip(@Param('id') id: string, @Body() _body: Record<string, unknown>) {
    return this.compatService.analysisClip(id);
  }

  @Delete('clips/:id')
  deleteClip(@Param('id') _id: string) {
    return this.compatService.emptyObject();
  }

  @Post('clips/:clipId/share')
  shareClip(
    @Param('clipId') _clipId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.shareClipResponse();
  }
}
