import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';
import { OnboardingService } from './onboarding.service';
import { OnboardingResolveDto } from './dto/onboarding-resolve.dto';

@ApiTags('onboarding')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('onboarding')
export class OnboardingController {
    constructor(private readonly onboardingService: OnboardingService) { }

    @Post('resolve')
    async resolve(@CurrentUser() user: JwtPayload, @Body() body: OnboardingResolveDto) {
        return this.onboardingService.resolve(user.sub, body);
    }

    @Post('complete')
    async complete(@CurrentUser() user: JwtPayload) {
        return this.onboardingService.complete(user.sub);
    }
}
