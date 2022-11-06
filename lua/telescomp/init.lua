local cmdline = require('telescomp.cmdline')

return {
  cmdline = cmdline,
  setup = function(opt)
    cmdline.setup(opt)
  end
}
