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
} from '@nestjs/common';
import { CompatService } from '../compat.service';

@Controller('cloud')
export class CloudCompatController {
  constructor(private readonly compatService: CompatService) {}

  @Get('files/bootstrap')
  bootstrap(@Query('teamId') teamId?: string) {
    return this.compatService.cloudFilesBootstrap(teamId);
  }

  @Get('files')
  files(@Query('teamId') teamId?: string) {
    const page = this.compatService.cloudFilesPage() as {
      items: unknown[];
      nextCursor: string | null;
    };
    if (teamId && page.items.length === 0) {
      return {
        ...page,
        items: [],
      };
    }
    return page;
  }

  @Get('files/largest')
  largest() {
    return this.compatService.emptyArray();
  }

  @Get('files/old')
  old() {
    return this.compatService.emptyArray();
  }

  @Post('folders')
  createFolder(@Body() body: Record<string, unknown>) {
    const teamId = typeof body.teamID === 'string' ? body.teamID : undefined;
    return this.compatService.cloudFolder(undefined, teamId);
  }

  @Put('folders/:folderId')
  updateFolder(
    @Param('folderId') folderId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.cloudFolder(folderId);
  }

  @Post('files/register')
  register(@Body() _body: Record<string, unknown>) {
    return this.compatService.cloudRegisterUploadResponse();
  }

  @Post('files/:fileId/complete')
  completeFile(
    @Param('fileId') fileId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.cloudFile(fileId);
  }

  @Patch('files/:fileId')
  updateFile(
    @Param('fileId') fileId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.cloudFile(fileId);
  }

  @Post('files/:fileId/move')
  moveFile(
    @Param('fileId') fileId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.cloudFile(fileId);
  }

  @Post('files/:fileId/trash')
  trashFile(
    @Param('fileId') fileId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.cloudFile(fileId);
  }

  @Post('files/:fileId/restore')
  restoreFile(
    @Param('fileId') fileId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.cloudFile(fileId);
  }

  @Delete('files/:fileId')
  deleteFile(@Param('fileId') _fileId: string) {
    return this.compatService.emptyObject();
  }
}
